/*******************************************************************/
// FemtoRV32, a collection of minimalistic RISC-V RV32 cores.
// This version: The "Quark", the most elementary version of FemtoRV32.
//             A single VERILOG file, compact & understandable code.
//             (200 lines of code, 400 lines counting comments)
//
// Instruction set: RV32I + CSR + MRET, con interrupciones
//   (mecanismo de interrupciones tomado de la versión "Intermissum")
//
// Parameters:
//  Reset address can be defined using RESET_ADDR (default is 0).
//
//  The ADDR_WIDTH parameter lets you define the width of the internal
//  address bus (and address computation logic).
//
// Bruno Levy, Matthias Koch, 2020-2021
//
// femto_UN (UNAL), versión para ASIC sky130 / Tiny Tapeout:
//  - Máquina de estados explícita: un bloque secuencial (registros) y un
//    bloque combinacional (salidas), ambos con case(state).
//  - Todo registro con estado se inicializa con reset (activo en bajo);
//    no se depende de bloques initial, que no existen en la netlist.
//  - Cada estado asigna todas las salidas combinacionales: no hay latches.
//  - Interrupciones: una línea interrupt_request; CSRs mstatus (MIE), mtvec,
//    mepc, mcause, cycle y cycleh; instrucciones CSRRW/S/C(I) y MRET.
/*******************************************************************/

// Firmware generation flags for this processor
`define NRV_ARCH     "rv32i"
`define NRV_ABI      "ilp32"
`define NRV_OPTIMIZE "-Os"
`define NRV_INTERRUPTS

module FemtoRV32(
   input 	 clk,

   output reg [31:0] mem_addr,  // address bus
   output [31:0] mem_wdata, // data to be written
   output reg [3:0]  mem_wmask, // write mask for the 4 bytes of each word
   input  [31:0] mem_rdata, // input lines for both data and instr
   output reg	 mem_rstrb, // active to initiate memory read (used by IO)
   input 	 mem_rbusy, // asserted if memory is busy reading value
   input 	 mem_wbusy, // asserted if memory is busy writing value

   input         interrupt_request, // petición de interrupción (activa en alto)

   input 	 reset      // set to 0 to reset the processor
);

   parameter RESET_ADDR       = 32'h00000000;
   parameter ADDR_WIDTH       = 24;

   // Estados de la máquina de estados (codificación one-hot)
   localparam FETCH_INSTR     = 4'b0001;
   localparam WAIT_INSTR      = 4'b0010;
   localparam EXECUTE         = 4'b0100;
   localparam WAIT_ALU_OR_MEM = 4'b1000;

   localparam NOP = 30'h00000004;  // addi x0, x0, 0 (bits [31:2])

   reg [3:0] state;
   reg       writeBack;   // escritura en el banco de registros

 /***************************************************************************/
 // Instruction decoding.
 /***************************************************************************/

 // Extracts rd,rs1,rs2,funct3,imm and opcode from instruction.
 // Reference: Table page 104 of:
 // https://content.riscv.org/wp-content/uploads/2017/05/riscv-spec-v2.2.pdf

 // The destination register
 wire [4:0] rdId = instr[11:7];

 // The ALU function, decoded in 1-hot form (doing so reduces LUT count)
 // It is used as follows: funct3Is[val] <=> funct3 == val
 (* onehot *)
 wire [7:0] funct3Is = 8'b00000001 << instr[14:12];

 // The five immediate formats, see RiscV reference (link above), Fig. 2.4 p. 12
 wire [31:0] Uimm = {    instr[31],   instr[30:12], {12{1'b0}}};
 wire [31:0] Iimm = {{21{instr[31]}}, instr[30:20]};
 /* verilator lint_off UNUSED */ // MSBs of SBJimms are not used by addr adder.
 wire [31:0] Simm = {{21{instr[31]}}, instr[30:25],instr[11:7]};
 wire [31:0] Bimm = {{20{instr[31]}}, instr[7],instr[30:25],instr[11:8],1'b0};
 wire [31:0] Jimm = {{12{instr[31]}}, instr[19:12],instr[20],instr[30:21],1'b0};
 /* verilator lint_on UNUSED */

   // Base RISC-V (RV32I) has only 10 different instructions !
   wire isLoad    =  (instr[6:2] == 5'b00000); // rd <- mem[rs1+Iimm]
   wire isALUimm  =  (instr[6:2] == 5'b00100); // rd <- rs1 OP Iimm
   wire isStore   =  (instr[6:2] == 5'b01000); // mem[rs1+Simm] <- rs2
   wire isALUreg  =  (instr[6:2] == 5'b01100); // rd <- rs1 OP rs2
   wire isSYSTEM  =  (instr[6:2] == 5'b11100); // rd <- CSR <- rs1/uimm5
   wire isJAL     =  instr[3]; // (instr[6:2] == 5'b11011); // rd <- PC+4; PC<-PC+Jimm
   wire isJALR    =  (instr[6:2] == 5'b11001); // rd <- PC+4; PC<-rs1+Iimm
   wire isLUI     =  (instr[6:2] == 5'b01101); // rd <- Uimm
   wire isAUIPC   =  (instr[6:2] == 5'b00101); // rd <- PC + Uimm
   wire isBranch  =  (instr[6:2] == 5'b11000); // if(rs1 OP rs2) PC<-PC+Bimm

   wire isALU = isALUimm | isALUreg;

   /***************************************************************************/
   // The register file.
   /***************************************************************************/


   reg [31:0] rs1;
   reg [31:0] rs2;
   
   reg [31:0] registerFile [31:0];

   // Escritura en posedge, al final del ciclo EXECUTE o WAIT_ALU_OR_MEM.
   // x0 se mantiene en 0 escribiéndolo en cada ciclo.
   always @(posedge clk) begin
     registerFile[0] <= 32'b0;
     if (writeBack && rdId != 0)
       registerFile[rdId] <= writeBackData;
   end


   /***************************************************************************/
   // The ALU. Does operations and tests combinatorially, except shifts.
   /***************************************************************************/

   // First ALU source, always rs1
   wire [31:0] aluIn1 = rs1;

   // Second ALU source, depends on opcode:
   //    ALUreg, Branch:     rs2
   //    ALUimm, Load, JALR: Iimm
   wire [31:0] aluIn2 = isALUreg | isBranch ? rs2 : Iimm;

   reg  [31:0] aluReg;       // The internal register of the ALU, used by shift.
   reg  [4:0]  aluShamt;     // Current shift amount.

   wire aluBusy = |aluShamt; // ALU is busy if shift amount is non-zero.
   reg  aluWr;               // ALU write strobe, starts shifting.

   // The adder is used by both arithmetic instructions and JALR.
   wire [31:0] aluPlus = aluIn1 + aluIn2;

   // Use a single 33 bits subtract to do subtraction and all comparisons
   // (trick borrowed from swapforth/J1)
   wire [32:0] aluMinus = {1'b1, ~aluIn2} + {1'b0,aluIn1} + 33'b1;
   wire        LT  = (aluIn1[31] ^ aluIn2[31]) ? aluIn1[31] : aluMinus[32];
   wire        LTU = aluMinus[32];
   wire        EQ  = (aluMinus[31:0] == 0);

   // Notes:
   // - instr[30] is 1 for SUB and 0 for ADD
   // - for SUB, need to test also instr[5] to discriminate ADDI:
   //    (1 for ADD/SUB, 0 for ADDI, and Iimm used by ADDI overlaps bit 30 !)
   // - instr[30] is 1 for SRA (do sign extension) and 0 for SRL

   wire [31:0] aluOut =
     (funct3Is[0]  ? instr[30] & instr[5] ? aluMinus[31:0] : aluPlus : 32'b0) |
     (funct3Is[2]  ? {31'b0, LT}                                     : 32'b0) |
     (funct3Is[3]  ? {31'b0, LTU}                                    : 32'b0) |
     (funct3Is[4]  ? aluIn1 ^ aluIn2                                 : 32'b0) |
     (funct3Is[6]  ? aluIn1 | aluIn2                                 : 32'b0) |
     (funct3Is[7]  ? aluIn1 & aluIn2                                 : 32'b0) |
     (funct3IsShift ? aluReg                                         : 32'b0) ;

   wire funct3IsShift = funct3Is[1] | funct3Is[5];

   always @(posedge clk) begin
      if (!reset) begin
         aluReg   <= 32'b0;
         aluShamt <= 5'b0;
      end else begin
         if(aluWr) begin
            if (funct3IsShift) begin  // SLL, SRA, SRL
              aluReg <= aluIn1;
              aluShamt <= aluIn2[4:0];
            end
         end
      // Compact form of:
      // funct3=001              -> SLL  (aluReg <= aluReg << 1)
      // funct3=101 &  instr[30] -> SRA  (aluReg <= {aluReg[31], aluReg[31:1]})
      // funct3=101 & !instr[30] -> SRL  (aluReg <= {1'b0,       aluReg[31:1]})

         if (|aluShamt) begin
            aluShamt <= aluShamt - 1;
            aluReg <= funct3Is[1] ? aluReg << 1 :              // SLL
            {instr[30] & aluReg[31], aluReg[31:1]};  // SRA,SRL
         end
      end
   end

   /***************************************************************************/
   // The predicate for conditional branches.
   /***************************************************************************/

   wire predicate =
        funct3Is[0] &  EQ  | // BEQ
        funct3Is[1] & !EQ  | // BNE
        funct3Is[4] &  LT  | // BLT
        funct3Is[5] & !LT  | // BGE
        funct3Is[6] &  LTU | // BLTU
        funct3Is[7] & !LTU ; // BGEU

   /***************************************************************************/
   // Program counter and branch target computation.
   /***************************************************************************/

   reg  [ADDR_WIDTH-1:0] PC; // The program counter.
   reg  [31:2] instr;        // Latched instruction. Note that bits 0 and 1 are
                             // ignored (not used in RV32I base instr set).

   wire [ADDR_WIDTH-1:0] PCplus4 = PC + 4;

   // An adder used to compute branch address, JAL address and AUIPC.
   // branch->PC+Bimm    AUIPC->PC+Uimm    JAL->PC+Jimm
   // Equivalent to PCplusImm = PC + (isJAL ? Jimm : isAUIPC ? Uimm : Bimm)
   wire [ADDR_WIDTH-1:0] PCplusImm = PC + ( instr[3] ? Jimm[ADDR_WIDTH-1:0] :
					    instr[4] ? Uimm[ADDR_WIDTH-1:0] :
					               Bimm[ADDR_WIDTH-1:0] );

   // A separate adder to compute the destination of load/store.
   // testing instr[5] is equivalent to testing isStore in this context.
   wire [ADDR_WIDTH-1:0] loadstore_addr = rs1[ADDR_WIDTH-1:0] +
		   (instr[5] ? Simm[ADDR_WIDTH-1:0] : Iimm[ADDR_WIDTH-1:0]);

   /* verilator lint_off WIDTH */
   // internal address registers and cycles counter may have less than 
   // 32 bits, so we deactivate width test for mem_addr and writeBackData


   /***************************************************************************/
   // Interrupciones, CSRs y MRET
   /***************************************************************************/

   // CSRs. Se escriben en el estado EXECUTE de la máquina de estados.
   reg  [ADDR_WIDTH-1:0] mepc;    // PC de retorno de la interrupción
   reg  [ADDR_WIDTH-1:0] mtvec;   // dirección de la rutina de interrupción
   reg                   mstatus; // MIE: habilitación global de interrupciones
   reg                   mcause;  // 1 mientras se atiende una interrupción
   reg  [63:0]           cycles;  // contador de ciclos

   always @(posedge clk)
      if (!reset) cycles <= 64'b0;
      else        cycles <= cycles + 1;

   // La petición se recuerda hasta que se acepta, porque solo se revisa
   // en EXECUTE. Una petición que llega durante la atención no se pierde.
   reg  interrupt_request_sticky;

   // Se atiende si está habilitada (mstatus) y no hay otra en curso (mcause).
   wire interrupt          = interrupt_request_sticky & mstatus & ~mcause;
   wire interrupt_accepted = interrupt & (state == EXECUTE);

   always @(posedge clk)
      if (!reset) interrupt_request_sticky <= 1'b0;
      else        interrupt_request_sticky <= interrupt_request |
                     (interrupt_request_sticky & ~interrupt_accepted);

   // MRET (SYSTEM con funct3 = 0)
   wire interrupt_return = isSYSTEM & funct3Is[0];

   // Selección del CSR (campo instr[31:20])
   wire sel_mstatus = (instr[31:20] == 12'h300);
   wire sel_mtvec   = (instr[31:20] == 12'h305);
   wire sel_mepc    = (instr[31:20] == 12'h341);
   wire sel_mcause  = (instr[31:20] == 12'h342);
   wire sel_cycles  = (instr[31:20] == 12'hC00);
   wire sel_cyclesh = (instr[31:20] == 12'hC80);

   // Lectura de CSRs
   /* verilator lint_off WIDTH */
   wire [31:0] CSR_read =
     (sel_mstatus ? {28'b0, mstatus, 3'b0} : 32'b0) |
     (sel_mtvec   ? mtvec                  : 32'b0) |
     (sel_mepc    ? mepc                   : 32'b0) |
     (sel_mcause  ? {mcause, 31'b0}        : 32'b0) |
     (sel_cycles  ? cycles[31:0]           : 32'b0) |
     (sel_cyclesh ? cycles[63:32]          : 32'b0) ;
   /* verilator lint_on WIDTH */

   // Escritura de CSRs: operando = inmediato de 5 bits (CSRRxI) o rs1 (CSRRx)
   wire [31:0] CSR_modifier = instr[14] ? {27'd0, instr[19:15]} : rs1;

   wire [31:0] CSR_write =
       (instr[13:12] == 2'b10) ?  CSR_modifier | CSR_read :  // CSRRS
       (instr[13:12] == 2'b11) ? ~CSR_modifier & CSR_read :  // CSRRC
                                  CSR_modifier ;              // CSRRW

   wire isCSRwrite = isSYSTEM & (instr[14:12] != 3'b000);

   /***************************************************************************/
   // The value written back to the register file.
   /***************************************************************************/

   wire [31:0] writeBackData  =
      (isSYSTEM            ? CSR_read   : 32'b0) |  // SYSTEM (CSR)
      (isLUI               ? Uimm       : 32'b0) |  // LUI
      (isALU               ? aluOut     : 32'b0) |  // ALUreg, ALUimm
      (isAUIPC             ? PCplusImm  : 32'b0) |  // AUIPC
      (isJALR   | isJAL    ? PCplus4    : 32'b0) |  // JAL, JALR
      (isLoad              ? LOAD_data  : 32'b0) ;  // Load
      
   /* verilator lint_on WIDTH */


   /***************************************************************************/
   // LOAD/STORE
   /***************************************************************************/

   // All memory accesses are aligned on 32 bits boundary. For this
   // reason, we need some circuitry that does unaligned halfword
   // and byte load/store, based on:
   // - funct3[1:0]:  00->byte 01->halfword 10->word
   // - mem_addr[1:0]: indicates which byte/halfword is accessed

   wire mem_byteAccess     = instr[13:12] == 2'b00; // funct3[1:0] == 2'b00;
   wire mem_halfwordAccess = instr[13:12] == 2'b01; // funct3[1:0] == 2'b01;

   // LOAD, in addition to funct3[1:0], LOAD depends on:
   // - funct3[2] (instr[14]): 0->do sign expansion   1->no sign expansion

   wire LOAD_sign =
	!instr[14] & (mem_byteAccess ? LOAD_byte[7] : LOAD_halfword[15]);

   wire [31:0] LOAD_data =
         mem_byteAccess ? {{24{LOAD_sign}},     LOAD_byte} :
     mem_halfwordAccess ? {{16{LOAD_sign}}, LOAD_halfword} :
                          mem_rdata ;

   wire [15:0] LOAD_halfword =
	       loadstore_addr[1] ? mem_rdata[31:16] : mem_rdata[15:0];

   wire  [7:0] LOAD_byte =
	       loadstore_addr[0] ? LOAD_halfword[15:8] : LOAD_halfword[7:0];

   // STORE

   assign mem_wdata[ 7: 0] = rs2[7:0];
   assign mem_wdata[15: 8] = loadstore_addr[0] ? rs2[7:0]  : rs2[15: 8];
   assign mem_wdata[23:16] = loadstore_addr[1] ? rs2[7:0]  : rs2[23:16];
   assign mem_wdata[31:24] = loadstore_addr[0] ? rs2[7:0]  :
			     loadstore_addr[1] ? rs2[15:8] : rs2[31:24];

   // The memory write mask:
   //    1111                     if writing a word
   //    0011 or 1100             if writing a halfword
   //                                (depending on loadstore_addr[1])
   //    0001, 0010, 0100 or 1000 if writing a byte
   //                                (depending on loadstore_addr[1:0])

   wire [3:0] STORE_wmask =
	      mem_byteAccess      ?
	            (loadstore_addr[1] ?
		          (loadstore_addr[0] ? 4'b1000 : 4'b0100) :
		          (loadstore_addr[0] ? 4'b0010 : 4'b0001)
                    ) :
	      mem_halfwordAccess ?
	            (loadstore_addr[1] ? 4'b1100 : 4'b0011) :
              4'b1111;

   /*************************************************************************/
   // Máquina de estados
   //
   //   FETCH_INSTR     : pide la instrucción en PC          (mem_rstrb = 1)
   //   WAIT_INSTR      : espera !mem_rbusy, captura instr, rs1 y rs2
   //   EXECUTE         : ejecuta, calcula el nuevo PC, inicia load/store/shift
   //   WAIT_ALU_OR_MEM : espera fin de shift, load o store
   /*************************************************************************/


   wire jumpToPCplusImm = isJAL | (isBranch & predicate);
   wire needToWait      = isLoad | isStore | (isALU & funct3IsShift);

   // Siguiente PC si no hay interrupción
   wire [ADDR_WIDTH-1:0] PC_new =
        isJALR           ? {aluPlus[ADDR_WIDTH-1:1], 1'b0} :
        jumpToPCplusImm  ? PCplusImm :
        interrupt_return ? mepc :
                           PCplus4;

   // ---------------------------------------------------------------------
   // Bloque secuencial: estado y registros de la ruta de datos
   // ---------------------------------------------------------------------
   always @(posedge clk) begin
      if (!reset) begin
         state     <= WAIT_ALU_OR_MEM;   // espera !mem_wbusy antes de arrancar
         PC        <= RESET_ADDR[ADDR_WIDTH-1:0];
         instr     <= NOP;
         rs1       <= 32'b0;
         rs2       <= 32'b0;
         mem_wmask <= 4'b0000;
         mstatus   <= 1'b0;              // interrupciones deshabilitadas
         mtvec     <= {ADDR_WIDTH{1'b0}};
         mepc      <= {ADDR_WIDTH{1'b0}};
         mcause    <= 1'b0;
      end else begin
         mem_wmask <= 4'b0000;           // por defecto, sin escritura

         case (state)

            FETCH_INSTR: begin
               state <= WAIT_INSTR;
            end

            WAIT_INSTR: begin
               if (!mem_rbusy) begin     // puede tardar (flash SPI)
                  rs1   <= registerFile[mem_rdata[19:15]];
                  rs2   <= registerFile[mem_rdata[24:20]];
                  instr <= mem_rdata[31:2];
                  state <= EXECUTE;
               end
            end

            EXECUTE: begin
               mem_wmask <= {4{isStore}} & STORE_wmask;  // visible en WAIT_ALU_OR_MEM

               if (interrupt) begin      // la instrucción actual termina y se
                  PC     <= mtvec;       // salta a la rutina de interrupción
                  mepc   <= PC_new;
                  mcause <= 1'b1;
               end else begin
                  PC <= PC_new;
                  if (interrupt_return)  // MRET: fin de la atención
                     mcause <= 1'b0;
               end

               if (isCSRwrite) begin     // CSRRW/S/C(I)
                  if (sel_mstatus) mstatus <= CSR_write[3];
                  if (sel_mtvec)   mtvec   <= CSR_write[ADDR_WIDTH-1:0];
               end

               state <= needToWait ? WAIT_ALU_OR_MEM : FETCH_INSTR;
            end

            WAIT_ALU_OR_MEM: begin
               if (!aluBusy && !mem_rbusy && !mem_wbusy)
                  state <= FETCH_INSTR;
            end

            default: begin               // código de estado inválido
               state <= FETCH_INSTR;
            end

         endcase
      end
   end

   // ---------------------------------------------------------------------
   // Bloque combinacional: salidas de la máquina de estados.
   // Cada estado (y el reset) asigna explícitamente las cuatro salidas:
   // ninguna queda sin valor en ningún camino, así no se infieren latches.
   // ---------------------------------------------------------------------
   /* verilator lint_off WIDTH */
   always @(*) begin
      if (!reset) begin
         mem_addr  = loadstore_addr;
         mem_rstrb = 1'b0;
         aluWr     = 1'b0;
         writeBack = 1'b0;
      end else begin
         case (state)
            FETCH_INSTR: begin
               mem_addr  = PC;
               mem_rstrb = 1'b1;
               aluWr     = 1'b0;
               writeBack = 1'b0;
            end
            WAIT_INSTR: begin
               mem_addr  = PC;
               mem_rstrb = 1'b0;
               aluWr     = 1'b0;
               writeBack = 1'b0;
            end
            EXECUTE: begin
               mem_addr  = loadstore_addr;
               mem_rstrb = isLoad;
               aluWr     = isALU;
               writeBack = ~(isBranch | isStore);
            end
            WAIT_ALU_OR_MEM: begin
               mem_addr  = loadstore_addr;
               mem_rstrb = 1'b0;
               aluWr     = 1'b0;
               writeBack = ~(isBranch | isStore);
            end
            default: begin             // código de estado inválido
               mem_addr  = loadstore_addr;
               mem_rstrb = 1'b0;
               aluWr     = 1'b0;
               writeBack = 1'b0;
            end
         endcase
      end
   end
   /* verilator lint_on WIDTH */

endmodule

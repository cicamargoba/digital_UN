import sys,json,argparse
from pathlib import Path
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT))
from extract_capture_activity import Capture,fit_lines

out=ROOT/'Docs'/'extraccion_025'
parser=argparse.ArgumentParser()
parser.add_argument('captures',type=Path,nargs=2,metavar=('D0','D1'))
args=parser.parse_args()
for channel,capture in enumerate(args.captures):
    cap=Capture(capture)
    start=450000000;length=48000000
    p=cap.levels(0,start,length);n=cap.levels(1,start,length)
    phase,H,quality=fit_lines(p,n)
    z=np.load(out/f'MIPI_VIDEO_025_D{channel}_muestras_derivadas.npz')
    rows=z['row_indices'];L=z['p'].shape[0]
    # Select early active rows by their measured activity, not their appearance.
    selected=rows[8:88]
    sums=[np.zeros(25000) for _ in range(3)]
    counts=np.zeros(25000)
    for frame in range(30):
        for row in selected:
            a=phase+(frame*L+int(row))*H
            if a<0 or a+250>=length:continue
            indices=np.arange(int(np.ceil(a)),int(np.floor(a+250)))
            bins=np.floor((indices-a)*100).astype(int)
            np.add.at(counts,bins,1)
            np.add.at(sums[0],bins,p[indices])
            np.add.at(sums[1],bins,n[indices])
            np.add.at(sums[2],bins,(p[indices]==0)&(n[indices]==0))
    valid=counts>0
    traces=[]
    for v in sums:
        a=np.full(len(v),np.nan);a[valid]=v[valid]/counts[valid];traces.append(a)
    t=np.arange(len(counts))*.1
    fig,axes=plt.subplots(2,1,figsize=(16,7),sharex=True)
    axes[0].plot(t,traces[0],label='P=1');axes[0].plot(t,traces[1],label='N=1');axes[0].legend()
    axes[1].plot(t,traces[2],label='P=N=0');axes[1].legend()
    axes[1].set_xlabel('Tiempo desde comienzo de LP11 [ns]');axes[0].set_ylabel('Fracción de observaciones')
    axes[0].set_title(f'D{channel}: muestreo equivalente de cabeceras repetidas; no son bits ya decodificados')
    for ax in axes:ax.grid(alpha=.2);ax.set_xlim(0,1500)
    fig.tight_layout();fig.savefig(out/f'MIPI_VIDEO_025_D{channel}_cabecera_equivalente.png',dpi=100);plt.close(fig)
    region=(t>750)&(t<1500)&valid
    stats=dict(channel=channel,line_samples=H,fit=quality,
               selected_rows=selected.tolist(),records=30*len(selected),
               bins_observed=int(valid.sum()),total_bins=len(valid),
               header_p_quantiles=np.nanpercentile(traces[0][region],[0,10,50,90,100]).tolist(),
               header_n_quantiles=np.nanpercentile(traces[1][region],[0,10,50,90,100]).tolist(),
               header_both_zero_mean=float(np.nanmean(traces[2][region])))
    np.savez_compressed(out/f'MIPI_VIDEO_025_D{channel}_cabecera_equivalente.npz',time_ns=t,counts=counts,p=traces[0],n=traces[1],both_zero=traces[2])
    (out/f'MIPI_VIDEO_025_D{channel}_cabecera_equivalente.json').write_text(json.dumps(stats,indent=2)+'\n')
    print(json.dumps(stats),flush=True)

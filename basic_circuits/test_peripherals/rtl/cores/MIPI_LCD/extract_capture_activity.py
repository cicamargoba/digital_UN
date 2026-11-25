from pathlib import Path
import argparse
import hashlib
import json
import mmap
import struct
import xml.etree.ElementTree as ET

import numpy as np
from PIL import Image
from scipy.ndimage import gaussian_filter1d


class Capture:
    def __init__(self, path):
        self.path = Path(path)
        self.file = self.path.open('rb')
        self.map = mmap.mmap(self.file.fileno(), 0, access=mmap.ACCESS_READ)
        k = self.map.find(b'kvdat', 0, 65536)
        assert k >= 0
        self.samples, self.rate = struct.unpack_from('<QQ', self.map, k + 8)
        xml_end = self.map.find(b'</settings>', 0, k) + len(b'</settings>')
        self.settings = ET.fromstring(self.map[:xml_end].decode())
        self.blocks = []
        p = k + 40
        while p < len(self.map):
            assert self.map[p:p+3] == b'##D'
            channel = self.map[p+4]
            initial = self.map[p+5]
            count = struct.unpack_from('<Q', self.map, p+8)[0]
            self.blocks.append((channel, initial, p+16, count))
            p += 16 + 5 * count
        assert p == len(self.map) and len(self.blocks) == 2

    def lower_bound(self, offset, count, value):
        lo, hi = 0, count
        while lo < hi:
            mid = (lo + hi) // 2
            t = int.from_bytes(self.map[offset+mid*5:offset+mid*5+5], 'little')
            if t < value:
                lo = mid + 1
            else:
                hi = mid
        return lo

    def levels(self, channel, start, length):
        number, initial, offset, count = self.blocks[channel]
        assert initial in (0, 1)
        begin = self.lower_bound(offset, count, start)
        end = self.lower_bound(offset, count, start+length)
        a = np.ndarray((end-begin, 5), dtype=np.uint8,
                       buffer=self.map, offset=offset+begin*5)
        times = np.zeros(end-begin, dtype=np.uint64)
        for i in range(5):
            times |= a[:, i].astype(np.uint64) << (8*i)
        assert np.all(times[1:] >= times[:-1])
        wave = np.zeros(length, dtype=np.uint8)
        wave[(times-start).astype(np.int64)] = 1
        np.bitwise_xor.accumulate(wave, out=wave)
        wave ^= initial ^ (begin % 2)
        return wave

    def metadata(self):
        return dict(file=self.path.name, bytes=self.path.stat().st_size,
                    samples=self.samples, sample_rate_hz=self.rate,
                    channels=[dict(channel=c, initial=i, transitions=n)
                              for c, i, _, n in self.blocks])


def runs(mask):
    d = np.flatnonzero(mask[1:] != mask[:-1]) + 1
    borders = np.r_[0, d, len(mask)]
    return borders[:-1][mask[borders[:-1]]], np.diff(borders)[mask[borders[:-1]]]


def fit_lines(p, n):
    starts, lengths = runs((p != 0) & (n != 0))
    candidates = starts[(lengths >= 12) & (lengths <= 80)]
    diffs = np.diff(candidates)
    short = diffs[(diffs >= 1000) & (diffs <= 10000)]
    bins = np.bincount(short.astype(int))
    rough = int(np.argmax(np.convolve(bins, np.ones(3), mode='same')))
    phase = float(candidates[0])
    period = float(rough)
    for _ in range(5):
        line = np.rint((candidates-phase)/period)
        residual = candidates - (phase+line*period)
        keep = np.abs(residual) < 10
        assert keep.sum() > 100
        period, phase = np.polyfit(line[keep], candidates[keep], 1)
    residual = candidates[keep] - (phase+line[keep]*period)
    return phase, period, dict(initial_period_samples=rough,
                              lp11_candidates=len(candidates),
                              fitted_candidates=int(keep.sum()),
                              residual_rms_samples=float(np.std(residual)))


def frame_lines(means):
    results = []
    for lag in range(100, min(1800, len(means)//2)):
        a, b = means[:-lag], means[lag:]
        results.append((lag, float(np.corrcoef(a, b)[0, 1])))
    peaks = [results[i] for i in range(1, len(results)-1)
             if results[i][1] >= results[i-1][1] and results[i][1] >= results[i+1][1]]
    best = max(value for _, value in peaks)
    selected = min(lag for lag, value in peaks if value >= best-.005)
    return selected, sorted(peaks, key=lambda v: -v[1])[:8]


def longest_interval(mask):
    starts, lengths = runs(mask)
    i = int(np.argmax(lengths))
    return int(starts[i]), int(starts[i]+lengths[i])


def extract(path, output, start_s=4.5, seconds=.48):
    cap = Capture(path)
    start = round(start_s * cap.rate)
    length = min(round(seconds * cap.rate), cap.samples-start)
    print('metadata', json.dumps(cap.metadata()), flush=True)
    print('read sample window', start, length, flush=True)
    p = cap.levels(0, start, length)
    n = cap.levels(1, start, length)
    probe = min(len(p), 8000000)
    phase, line_period, quality = fit_lines(p[:probe], n[:probe])
    print('line fit', phase, line_period, quality, flush=True)
    boundaries = np.rint(phase+np.arange(int((length-phase)/line_period))*line_period).astype(int)
    means = np.array([p[a:b].mean() for a, b in zip(boundaries[:-1], boundaries[1:])])
    rows_per_frame, peaks = frame_lines(means)
    frame_period = line_period*rows_per_frame
    print('frame rows', rows_per_frame, 'period samples', frame_period, 'correlation', peaks, flush=True)
    frames = int((length-phase)/frame_period)
    width = int(round(line_period))
    raw_p = np.zeros((rows_per_frame, width), dtype=np.float64)
    raw_n = np.zeros_like(raw_p)
    x = np.arange(width)
    for frame in range(frames):
        for row in range(rows_per_frame):
            a = phase+frame*frame_period+row*line_period
            positions = np.rint(a+x*line_period/width).astype(int)
            raw_p[row] += p[positions]
            raw_n[row] += n[positions]
    raw_p /= frames
    raw_n /= frames
    horizontal = gaussian_filter1d(raw_p.mean(0), sigma=6)
    middle = horizontal[(horizontal > .04) & (horizontal < .6)]
    threshold = float(np.median(middle)*.35)
    left, right = longest_interval(horizontal > threshold)
    row_activity = raw_p[:, left:right].mean(1)
    active = (row_activity > .03) & (row_activity < .75)
    a, b = longest_interval(np.r_[active, active])
    b = min(b, a+rows_per_frame)
    row_indices = np.arange(a, b) % rows_per_frame
    cropped = raw_p[row_indices, left:right]
    # Pool a fixed number of time samples. No native pixel resolution or square aspect is assumed.
    pooling = 4
    columns = cropped.shape[1]//pooling
    image = cropped[:, :columns*pooling].reshape(len(cropped), columns, pooling).mean(2)
    scale = float(np.percentile(image, 99.5))
    assert scale > 0
    output.mkdir(parents=True, exist_ok=True)
    stem = cap.path.stem
    Image.fromarray(np.uint8(np.clip(raw_p, 0, 1)*255)).save(output/(stem+'_actividad_cuadro.png'))
    Image.fromarray(np.uint8(np.clip(image, 0, 1)*255)).save(output/(stem+'_actividad_sin_normalizar.png'))
    Image.fromarray(np.uint8(np.clip(image/scale, 0, 1)*255)).save(output/(stem+'_actividad_gris.png'))
    u = np.uint8(np.clip(image, 0, 1)*255)
    histogram = np.bincount(u.ravel(), minlength=256).astype(float)
    count = np.cumsum(histogram)
    moment = np.cumsum(histogram*np.arange(256))
    denominator = count*(count[-1]-count)
    score = np.zeros(256)
    usable = denominator > 0
    score[usable] = (moment[-1]*count[usable]-moment[usable]*count[-1])**2/denominator[usable]
    threshold = int(np.argmax(score))
    Image.fromarray(np.uint8(u > threshold)*255).save(output/(stem+'_segmentacion_actividad.png'))
    np.savez_compressed(output/(stem+'_muestras_derivadas.npz'), p=raw_p, n=raw_n,
                        row_indices=row_indices, left=left, right=right,
                        phase=phase, line_period=line_period, frame_period=frame_period)
    states, counts = np.unique((p[:probe]<<1) | n[:probe], return_counts=True)
    cap.file.seek(0)
    source_hash = hashlib.file_digest(cap.file, 'sha256').hexdigest()
    report = cap.metadata() | dict(
        source_sha256=source_hash,
        input_policy='Solo el archivo kvdat especificado; ninguna fotografía ni imagen previa.',
        method='Media de actividad digital P, alineada por LP11 y periodicidad de cuadro. No decodificación RGB.',
        sample_window=[start, start+length], frame_count=frames,
        line_period_samples=float(line_period), frame_period_samples=float(frame_period),
        frame_rate_hz=float(cap.rate/frame_period), frame_period_lines=rows_per_frame,
        fit_quality=quality, periodicity_peaks=peaks,
        crop_sample_columns=[left, right], crop_period_rows=[a,b],
        output_array_shape=list(image.shape), samples_pooled_per_column=pooling,
        native_pixel_resolution='no establecida', rgb_pixels_decoded=False,
        contrast_mapping=dict(offset=0, upper_level=scale, percentile=99.5),
        binary_mapping=dict(method='Otsu, umbral global calculado exclusivamente desde las muestras',
                            threshold_8bit=threshold, morphological_edits=False,
                            color_assignment=False),
        digital_state_counts={f'{state:02b}': int(count) for state,count in zip(states,counts)})
    (output/(stem+'_extraccion.json')).write_text(json.dumps(report, indent=2)+'\n')
    print(json.dumps(report, indent=2), flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('capture', type=Path)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--start', type=float, default=4.5)
    parser.add_argument('--seconds', type=float, default=.48)
    args = parser.parse_args()
    extract(args.capture, args.output, args.start, args.seconds)

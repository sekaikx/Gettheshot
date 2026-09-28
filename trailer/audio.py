import numpy as np, wave
SR = 44100; D = 30.5
N = int(SR * D)
L = np.zeros(N); R = np.zeros(N)
rng = np.random.default_rng(7)
def nf(n): return 440 * 2 ** ((n - 69) / 12)
NOTE = {'C':0,'D':2,'Eb':3,'E':4,'F':5,'G':7,'Ab':8,'A':9,'Bb':10,'B':11}
def m(name):  # 'Eb5'
    return NOTE[name[:-1]] + 12 * (int(name[-1]) + 1)
def add(sig, t0, pan=0.0, gain=1.0):
    i = int(t0 * SR); j = min(N, i + len(sig))
    if j <= i: return
    s = sig[:j - i] * gain
    L[i:j] += s * (1 - pan) ; R[i:j] += s * (1 + pan)
def env(n, a, r):
    e = np.ones(n); na = max(1, int(a * SR)); nr = max(1, int(r * SR))
    e[:na] = np.linspace(0, 1, na); e[-nr:] *= np.linspace(1, 0, nr); return e
def lowpass(x, k):
    # one-pole
    y = np.zeros_like(x); a = k; acc = 0.0
    for i in range(len(x)): acc += a * (x[i] - acc); y[i] = acc
    return y
def pluck(f, dur, amp=0.3):
    n = int(dur * SR); t = np.arange(n) / SR
    s = sum((0.9 ** h) / h * np.sin(2 * np.pi * f * h * t) * np.exp(-t * (3 + h * 1.6)) for h in range(1, 9))
    return amp * s * env(n, 0.002, 0.05)
def mandolin(f, dur, amp=0.18):  # tremolo picking
    n = int(dur * SR); out = np.zeros(n); step = 0.065; k = 0
    while k * step < dur - 0.05:
        p = pluck(f, 0.25, amp * (0.8 + 0.2 * ((k % 2) == 0))) + pluck(f * 1.003, 0.25, amp * 0.5)
        i = int(k * step * SR); j = min(n, i + len(p)); out[i:j] += p[:j - i]; k += 1
    return out * env(n, 0.01, 0.15)
def pad(freqs, dur, amp=0.05, a=1.0, r=1.5):
    n = int(dur * SR); t = np.arange(n) / SR; s = np.zeros(n)
    for f in freqs:
        for det in (-0.3, 0.3):
            ph = 2 * np.pi * (f + det) * t
            s += np.sin(ph) + 0.35 * np.sin(2 * ph) + 0.15 * np.sin(3 * ph)
    s *= (1 + 0.15 * np.sin(2 * np.pi * 5 * t))  # string vibrato-ish swell
    return amp * s / len(freqs) * env(n, a, r)
def boom(dur=2.5, amp=0.9, f0=90, f1=28):
    n = int(dur * SR); t = np.arange(n) / SR
    f = f1 + (f0 - f1) * np.exp(-t * 6); ph = 2 * np.pi * np.cumsum(f) / SR
    s = np.sin(ph) * np.exp(-t * 1.6)
    s += lowpass(rng.standard_normal(n) * np.exp(-t * 5), 0.05) * 0.8
    return amp * s
def gunshot(amp=0.9):
    n = int(0.9 * SR); t = np.arange(n) / SR
    s = rng.standard_normal(n) * np.exp(-t * 18) + lowpass(rng.standard_normal(n), 0.08) * np.exp(-t * 4) * 1.5
    s += np.sin(2 * np.pi * 60 * t) * np.exp(-t * 10)
    return amp * np.tanh(s * 2) * 0.6
def click(amp=0.25, f=2400):
    n = int(0.03 * SR); t = np.arange(n) / SR
    return amp * (rng.standard_normal(n) * 0.6 + np.sin(2 * np.pi * f * t)) * np.exp(-t * 250)
def thud(amp=0.6):
    n = int(0.5 * SR); t = np.arange(n) / SR
    return amp * (np.sin(2 * np.pi * (120 * np.exp(-t * 8) + 45) * t) * np.exp(-t * 9) + lowpass(rng.standard_normal(n), 0.1) * np.exp(-t * 25))
def whoosh(dur=0.5, amp=0.35):
    n = int(dur * SR); t = np.arange(n) / SR
    s = lowpass(rng.standard_normal(n), 0.15) * np.sin(np.pi * t / dur) ** 2
    return amp * s
def heartbeat(amp=0.5):
    return np.concatenate([thud(amp)[:int(0.22 * SR)], thud(amp * 0.7)])

# --- rain bed 0-3.4 and under title
n = int(4.0 * SR); rain = lowpass(rng.standard_normal(n), 0.35) * 0.05 * env(n, 0.5, 1.0); add(rain, 0, gain=1)
n = int(3.5 * SR); add(lowpass(rng.standard_normal(n), 0.35) * 0.035 * env(n, 0.8, 1.0), 27.0)
# low drone opening
add(pad([nf(36), nf(43)], 3.8, amp=0.10, a=1.2, r=1.0), 0)
# typewriter
for i in range(23): add(click(0.18, 1800 + rng.random() * 800), 0.3 + i / 20, pan=rng.uniform(-.2, .2))
add(click(0.3, 900), 1.5)  # carriage

# --- waltz theme 3.4 - 13.2
B = 0.714; T0 = 3.4
mel = [('G4',1),('C5',1),('Eb5',1),('D5',2),('C5',1),('Ab4',1),('C5',1),('F5',1),('Eb5',2),('D5',1),
       ('C5',1),('B4',1),('D5',1),('C5',3)]
t = T0
for nm, b in mel:
    add(mandolin(nf(m(nm)), b * B + 0.05), t, pan=0.15); t += b * B
chords = [(['C3'], ['G3','C4','Eb4']), (['G2'], ['G3','B3','D4']), (['F2'], ['F3','Ab3','C4']), (['G2'], ['G3','C4','Eb4']), (['G2'], ['F3','B3','D4']), (['C3'], ['G3','C4','Eb4']), (['C3'],['G3','C4','Eb4'])]
for bi, (bass, ch) in enumerate(chords):
    bt = T0 + bi * 3 * B
    if bt > 13.2: break
    add(pluck(nf(m(bass[0])), 1.2, 0.45), bt, pan=-0.1)
    for k in (1, 2):
        for c in ch: add(pluck(nf(m(c)), 0.5, 0.10), bt + k * B, pan=-0.2)
add(pad([nf(m(x)) for x in ['C3','G3','Eb4']], 10.0, amp=0.05, a=2.5, r=1.5), T0)

# chip "coin" blips
for tt in [4.6, 5.8, 7.0, 9.0, 10.2, 11.4, 12.2]:
    add(pluck(nf(88), 0.3, 0.08) + pluck(nf(95), 0.3, 0.06), tt, pan=0.3)

# --- sit-down tension 13.2 - 16.85
add(pad([nf(m(x)) for x in ['C3','G3','Ab3','D4']], 3.8, amp=0.07, a=0.6, r=0.3), 13.1)
for i in range(8): add(click(0.2, 3000 if i % 2 else 2200), 13.3 + i * 0.45)  # clock tick
for nm, tt in [('Eb5', 13.6), ('D5', 14.3), ('C5', 15.0)]: add(mandolin(nf(m(nm)), 0.6, 0.12), tt)
add(click(0.35, 1200), 15.2)    # mouse click
add(thud(0.7), 15.3)            # stamp
# --- betrayal
add(gunshot(1.0), 17.0, pan=0.1); add(boom(3.0, 0.8), 17.0)
for i in range(4): add(heartbeat(0.45), 17.6 + i * 0.75)
n = int(3.2 * SR); tt = np.arange(n) / SR  # string tremolo cluster
trem = sum(np.sin(2 * np.pi * nf(m(x)) * tt) for x in ['C4','Db4' if False else 'D4','Eb4']) * (0.5 + 0.5 * np.sign(np.sin(2 * np.pi * 12 * tt)))
add(0.03 * trem * env(n, 0.3, 0.3), 17.1)
add(mandolin(nf(m('G5')), 0.5, 0.15) + 0, 18.9); add(mandolin(nf(m('Ab5')), 0.8, 0.15), 19.2)  # alert sting
# --- era change
add(whoosh(0.6, 0.4), 20.0); add(boom(2.8, 0.7, 70, 25), 20.35)
n = int(1.0 * SR); tt = np.arange(n) / SR
fall = np.sin(2 * np.pi * np.cumsum(300 * np.exp(-tt * 2.5) + 60) / SR) * env(n, 0.02, 0.3) * 0.12
add(fall, 20.9)
add(pad([nf(m(x)) for x in ['F2','C3','Ab3']], 3.8, amp=0.08, a=0.8, r=0.6), 20.4)
# --- montage hits
for i, tt in enumerate([24.0, 25.0, 26.0]):
    add(whoosh(0.35, 0.35), tt - 0.3); add(thud(0.8), tt); add(click(0.5, 5000), tt)  # camera flash
    add(pluck(nf(m(['C3','Ab2','G2'][i])), 1.0, 0.5), tt)
    for k in range(3): add(thud(0.25), tt + 0.33 * (k + 1))
add(pad([nf(m(x)) for x in ['C3','G3','Eb4','G4']], 3.0, amp=0.06, a=1.5, r=0.2), 24.0)
# --- title
add(boom(3.3, 1.0, 80, 24), 27.1)
for nm, tt in [('G4', 27.3), ('C5', 27.3 + B), ('Eb5', 27.3 + 2 * B)]: add(mandolin(nf(m(nm)), 3.0 - (tt - 27.3), 0.14), tt)
add(pad([nf(m(x)) for x in ['C2','C3','G3','Eb4']], 3.3, amp=0.10, a=0.3, r=1.6), 27.1)

# simple reverb: multi-tap feedback-ish
def verb(x):
    y = x.copy()
    for d, g in [(0.031, .35), (0.047, .3), (0.071, .25), (0.113, .2), (0.167, .15), (0.241, .12), (0.353, .08)]:
        k = int(d * SR); y[k:] += x[:-k] * g
    return y
L = verb(L); R = verb(R[::-1])[::-1] * 0 + verb(R)
mx = max(np.abs(L).max(), np.abs(R).max()); L = np.tanh(L / mx * 1.4) * 0.9; R = np.tanh(R / mx * 1.4) * 0.9
fade = int(0.5 * SR); L[-fade:] *= np.linspace(1, 0, fade); R[-fade:] *= np.linspace(1, 0, fade)
data = (np.stack([L, R], 1) * 32767).astype(np.int16)
with wave.open('score.wav', 'wb') as w:
    w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR); w.writeframes(data.tobytes())
print('ok', data.shape)

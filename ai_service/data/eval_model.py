"""
Đánh giá đầy đủ model với dataset mới (250 epochs).
Xuất ra: metrics chi tiết, phân tích lỗi theo loại ngày.
"""
import sys, warnings, torch, torch.nn as nn
warnings.filterwarnings('ignore')
sys.path.insert(0, '..')
import importlib
import app.forecast_features as ff; importlib.reload(ff)
import app.forecast_net as fn; importlib.reload(fn)
import app.forecast_infer as fi; importlib.reload(fi)

import numpy as np, pandas as pd
from app.forecast_features import N_TIME_AND_CAT, N_CATEGORY, calendar_feats_numpy, category_shares_from_df
from app.forecast_net import SpendingForecastTransformer
from app.forecast_infer import predict_horizon_vnd, ForecastBundle
from torch.utils.data import DataLoader, TensorDataset

WINDOW, HORIZON = 30, 7
INPUT_SIZE  = 1 + N_TIME_AND_CAT
INST_NORM_K = 14
D_MODEL     = 64
N_HEADS     = 4
N_ENC_LAYERS = 3
N_DEC_LAYERS = 2
D_FF        = 256
MIN_VND = 50_000.0
eps = 1e-8
EPOCHS = 300
PATIENCE = 40
BATCH = 32
N_AUG = 7
VAL_DAYS = 60

df = pd.read_csv('daily_spending_train.csv', parse_dates=['date'])
df = df.sort_values('date').reset_index(drop=True)
series_raw = df['total_expense_vnd'].values.astype(float)
series_raw = np.maximum(series_raw, MIN_VND)

log_raw  = np.log1p(series_raw)
mean_log = float(log_raw.mean())
std_log  = float(max(log_raw.std(), 1e-6))
log_norm = (log_raw - mean_log) / (std_log + eps)
shares   = category_shares_from_df(df)
cal_all  = calendar_feats_numpy(df['date'].values.astype('datetime64[D]'))

def make_w(ln, cal, sh, W, H):
    n = len(ln)-W-H+1
    X,Y,D=[],[],[]
    for i in range(n):
        X.append(np.concatenate([ln[i:i+W].reshape(-1,1), cal[i:i+W], sh[i:i+W]], axis=1))
        Y.append(ln[i+W:i+W+H])
        D.append(np.concatenate([cal[i+W:i+W+H], sh[i+W:i+W+H]], axis=1))
    return np.array(X,np.float32), np.array(Y,np.float32), np.array(D,np.float32)

X,Y,D = make_w(log_norm, cal_all, shares, WINDOW, HORIZON)
nv = max(1, VAL_DAYS-HORIZON+1)
Xv,Yv,Dv = X[-nv:],Y[-nv:],D[-nv:]
n_base_tr = len(X) - nv
Xt_parts, Yt_parts, Dt_parts = [X[:n_base_tr]], [Y[:n_base_tr]], [D[:n_base_tr]]

# Augmentation
rng_np = np.random.default_rng(42)
for _ in range(N_AUG):
    scale = rng_np.uniform(0.85, 1.15)
    noise = rng_np.normal(0, series_raw.mean()*0.02, len(series_raw))
    aug   = np.maximum(series_raw*scale+noise, 1.0)
    aln   = (np.log1p(aug) - mean_log) / (std_log + eps)
    Xa,Ya,Da = make_w(aln.astype(np.float32), cal_all, shares, WINDOW, HORIZON)
    Xt_parts.append(Xa); Yt_parts.append(Ya); Dt_parts.append(Da)

Xt = np.concatenate(Xt_parts); Yt = np.concatenate(Yt_parts); Dt = np.concatenate(Dt_parts)

dl = DataLoader(TensorDataset(torch.from_numpy(Xt),torch.from_numpy(Yt),torch.from_numpy(Dt)),
    batch_size=BATCH, shuffle=True, drop_last=True)
dv = DataLoader(TensorDataset(torch.from_numpy(Xv),torch.from_numpy(Yv),torch.from_numpy(Dv)), batch_size=BATCH)

print(f"Train={len(Xt):,}  Val={len(Xv)}  (base train={n_base_tr}, aug x{N_AUG})")
print(f"mean_log={mean_log:.4f}  std_log={std_log:.4f}")

model = SpendingForecastTransformer(
    window=WINDOW, horizon=HORIZON, input_size=INPUT_SIZE,
    d_model=D_MODEL, n_heads=N_HEADS, n_enc_layers=N_ENC_LAYERS, n_dec_layers=N_DEC_LAYERS,
    d_ff=D_FF, dropout=0.10, use_instance_norm=True, inst_norm_recent_k=INST_NORM_K,
)
opt   = torch.optim.AdamW(model.parameters(), lr=3e-4, weight_decay=1e-4)
sched = torch.optim.lr_scheduler.CosineAnnealingLR(opt, T_max=EPOCHS, eta_min=3e-4*0.05)
loss_fn = nn.HuberLoss(delta=1.0)

best_val, best_state, no_imp = 9999.0, None, 0
for ep in range(1, EPOCHS+1):
    tf = 0.5 + (0.05-0.5)*(ep-1)/max(EPOCHS-1,1)
    model.train(); tl=0
    for bx,by,bd in dl:
        opt.zero_grad()
        loss_fn(model(bx,y_target=by,teacher_forcing_ratio=tf,decoder_time_feats=bd),by).backward()
        nn.utils.clip_grad_norm_(model.parameters(),1.0); opt.step()
        tl += loss_fn(model(bx,decoder_time_feats=bd).detach(),by).item()*len(bx)
    sched.step()
    model.eval(); vl=0
    with torch.no_grad():
        for bx,by,bd in dv:
            vl += loss_fn(model(bx,decoder_time_feats=bd),by).item()*len(bx)
    tl/=len(Xt); vl/=max(len(Xv),1)
    if vl < best_val-1e-6:
        best_val=vl; best_state={k:v.cpu().clone() for k,v in model.state_dict().items()}; no_imp=0
    else:
        no_imp+=1
    if ep%50==0 or ep==1:
        print(f"  Ep{ep:3d}: train={tl:.4f}  val={vl:.4f}  lr={sched.get_last_lr()[0]:.2e}")
    if no_imp >= PATIENCE:
        print(f"  Early stop ep{ep} best_val={best_val:.4f}")
        break

if best_state: model.load_state_dict(best_state)
print(f"\nBest val loss: {best_val:.4f}")

# ── Evaluate ──────────────────────────────────────────────────────────────────
model.eval()
pv, tv = [], []
with torch.no_grad():
    for bx,by,bd in dv:
        pv.append(model(bx,decoder_time_feats=bd).cpu().numpy())
        tv.append(by.cpu().numpy())
pv = np.concatenate(pv); tv = np.concatenate(tv)

def denorm(z):
    return np.expm1(np.clip(z*(std_log+eps)+mean_log, 0, 25))

pred_vnd = denorm(pv)
tgt_vnd  = denorm(tv)

mae  = np.mean(np.abs(pred_vnd - tgt_vnd))
rmse = np.sqrt(np.mean((pred_vnd - tgt_vnd)**2))
mape = np.mean(np.abs(pred_vnd - tgt_vnd) / (tgt_vnd + 1)) * 100

print(f"\n{'='*50}")
print(f"  MAE  : {mae:>12,.0f} VND  ({mae/tgt_vnd.mean()*100:.1f}% of mean)")
print(f"  RMSE : {rmse:>12,.0f} VND")
print(f"  MAPE : {mape:>11.2f} %")
print(f"  Mean predicted: {pred_vnd.mean():>10,.0f} VND")
print(f"  Mean actual   : {tgt_vnd.mean():>10,.0f} VND")
print(f"{'='*50}")

# MAPE theo horizon step
print("\n  MAPE theo buoc du bao:")
for h in range(HORIZON):
    m = np.mean(np.abs(pred_vnd[:,h]-tgt_vnd[:,h])/(tgt_vnd[:,h]+1))*100
    print(f"    Ngay +{h+1}: {m:.2f}%")

# MAPE theo thu trong tuan (val period dates)
val_dates = df['date'].iloc[-(nv+HORIZON):-HORIZON].reset_index(drop=True)
print("\n  MAPE theo thu trong tuan (ngay du bao trung binh):")
dow_names = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun']
for d in range(7):
    mask = val_dates.dt.dayofweek == d
    if mask.sum() == 0: continue
    p = pred_vnd[mask.values].flatten(); t = tgt_vnd[mask.values].flatten()
    m = np.mean(np.abs(p-t)/(t+1))*100
    print(f"    {dow_names[d]}: {m:.2f}%  (n={mask.sum()})")

# Quick Tet period check
print("\n  Tet 2025 (Jan 29) – du bao vs thuc te:")
tet_mask = (df['date'] >= '2025-01-20') & (df['date'] <= '2025-02-10')
tet_df   = df[tet_mask]
bundle = ForecastBundle(model=model, meta={
    'window':WINDOW,'horizon':HORIZON,'mean_log':mean_log,'std_log':std_log,
    'input_size':INPUT_SIZE,'n_category':N_CATEGORY,'mean_category':shares.mean(0).tolist(),
    'use_instance_norm':True,'inst_norm_recent_k':INST_NORM_K,'hidden_size':64,'num_layers':2,'dropout':0.3,'architecture':'seq2seq'
}, device=torch.device('cpu'))

# Predict from Jan 19 (before Tet)
jan19_idx = df[df['date']=='2025-01-19'].index[0]
if jan19_idx >= WINDOW:
    tail = series_raw[jan19_idx-WINDOW+1:jan19_idx+1].tolist()
    preds = predict_horizon_vnd(bundle, tail, last_date='2025-01-19')
    print(f"    Cuoi chuoi (2025-01-19): {int(tail[-1]):,} VND")
    print(f"    Du bao 7 ngay (Jan20-26): {[f'{p:,}' for p in preds]}")
    actual = df[(df['date']>='2025-01-20') & (df['date']<='2025-01-26')]['total_expense_vnd'].tolist()
    print(f"    Thuc te      (Jan20-26): {[f'{int(v):,}' for v in actual]}")

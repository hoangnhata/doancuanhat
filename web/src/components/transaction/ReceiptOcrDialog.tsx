import {
  Alert,
  Box,
  Button,
  CircularProgress,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  IconButton,
  Stack,
  TextField,
  Typography,
} from '@mui/material';
import {
  AutoAwesomeRounded,
  CloseRounded,
  DocumentScannerRounded,
  PhotoLibraryRounded,
  ReplayRounded,
  WarningAmberRounded,
} from '@mui/icons-material';
import { useRef, useState } from 'react';
import { extractApiError } from '@/lib/api';
import * as transactionService from '@/services/transactionService';
import type { OcrReceiptResult } from '@/services/transactionService';
import type { AICategorizeResponse } from '@/types/models';

interface Props {
  open: boolean;
  onClose: () => void;
  onApply: (result: OcrReceiptResult) => void;
}

function formatVnd(v: number | null): string {
  if (v == null) return '—';
  return new Intl.NumberFormat('vi-VN').format(Math.round(v)) + ' ₫';
}

export function ReceiptOcrDialog({ open, onClose, onApply }: Props) {
  const fileInputRef = useRef<HTMLInputElement>(null);
  const [imgUrl, setImgUrl] = useState<string | null>(null);
  const [file, setFile] = useState<File | null>(null);
  const [ocrLoading, setOcrLoading] = useState(false);
  const [classifyLoading, setClassifyLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [classifyError, setClassifyError] = useState<string | null>(null);

  const [ocrAmount, setOcrAmount] = useState<number | null>(null);
  const [ocrDate, setOcrDate] = useState<string | null>(null);
  const [ocrNeedsReview, setOcrNeedsReview] = useState(false);
  const [ocrEngine, setOcrEngine] = useState<string | null>(null);
  const [ocrConfidence, setOcrConfidence] = useState<number | null>(null);

  const [description, setDescription] = useState('');
  const [classifyResult, setClassifyResult] = useState<AICategorizeResponse | null>(null);

  function reset() {
    if (imgUrl) URL.revokeObjectURL(imgUrl);
    setImgUrl(null);
    setFile(null);
    setOcrAmount(null);
    setOcrDate(null);
    setOcrNeedsReview(false);
    setOcrEngine(null);
    setOcrConfidence(null);
    setDescription('');
    setClassifyResult(null);
    setError(null);
    setClassifyError(null);
    setOcrLoading(false);
    setClassifyLoading(false);
  }

  function handleClose() {
    reset();
    onClose();
  }

  async function handleFile(f: File) {
    if (!f.type.startsWith('image/')) {
      setError('Vui lòng chọn tệp ảnh (JPG/PNG).');
      return;
    }
    if (f.size > 10 * 1024 * 1024) {
      setError('Ảnh tối đa 10 MB.');
      return;
    }
    if (imgUrl) URL.revokeObjectURL(imgUrl);
    const url = URL.createObjectURL(f);
    setImgUrl(url);
    setFile(f);
    setOcrAmount(null);
    setOcrDate(null);
    setClassifyResult(null);
    setDescription('');
    setError(null);
    setClassifyError(null);
    setOcrLoading(true);
    try {
      const r = await transactionService.ocrReceipt(f);
      setOcrAmount(r.amount);
      setOcrDate(r.transactionDate);
      setOcrNeedsReview(r.needsReview);
      setOcrEngine(r.ocrEngine);
      setOcrConfidence(r.confidence);
    } catch (e) {
      setError(extractApiError(e));
    } finally {
      setOcrLoading(false);
    }
  }

  async function runClassify() {
    const text = description.trim();
    if (!text) {
      setClassifyError('Vui lòng nhập mô tả chuyển khoản.');
      return;
    }
    setClassifyLoading(true);
    setClassifyError(null);
    try {
      const r = await transactionService.aiCategorize(text);
      setClassifyResult(r);
    } catch (e) {
      setClassifyError(extractApiError(e));
    } finally {
      setClassifyLoading(false);
    }
  }

  const canApply =
    ocrAmount != null &&
    ocrAmount > 0 &&
    classifyResult != null &&
    !ocrLoading &&
    !classifyLoading;

  function applyAndClose() {
    if (!classifyResult || ocrAmount == null) return;
    const result: OcrReceiptResult = {
      transactionType: classifyResult.transactionType,
      amount: ocrAmount,
      transactionDate: ocrDate ?? classifyResult.transactionDate,
      merchant: null,
      description:
        classifyResult.description?.trim() || description.trim() || null,
      categoryName: classifyResult.categoryName,
      categoryId: classifyResult.categoryId,
      confidence: ocrConfidence,
      needsReview: ocrNeedsReview || classifyResult.categoryId == null,
      ocrEngine,
      bankTransfer: true,
      senderName: null,
      recipientName: null,
    };
    onApply(result);
    handleClose();
  }

  return (
    <Dialog
      open={open}
      onClose={handleClose}
      fullWidth
      maxWidth="sm"
      PaperProps={{ sx: { borderRadius: 3 } }}
    >
      <DialogTitle sx={{ display: 'flex', alignItems: 'center', gap: 1, fontWeight: 800 }}>
        <DocumentScannerRounded color="primary" />
        <Box flex={1}>Quét bill chuyển khoản</Box>
        <IconButton onClick={handleClose} size="small">
          <CloseRounded />
        </IconButton>
      </DialogTitle>
      <DialogContent dividers>
        <input
          ref={fileInputRef}
          type="file"
          accept="image/*"
          capture="environment"
          hidden
          onChange={(e) => {
            const f = e.target.files?.[0];
            if (f) handleFile(f);
            e.target.value = '';
          }}
        />

        {!file ? (
          <Box>
            <Typography color="text.secondary" sx={{ mb: 2 }}>
              Chọn ảnh bill chuyển khoản. AI đọc số tiền và ngày, sau đó bạn nhập mô tả để
              phân loại danh mục.
            </Typography>
            <Stack direction={{ xs: 'column', sm: 'row' }} spacing={1.5}>
              <Button
                fullWidth
                size="large"
                variant="contained"
                startIcon={<DocumentScannerRounded />}
                onClick={() => fileInputRef.current?.click()}
              >
                Chụp / Chọn ảnh
              </Button>
              <Button
                fullWidth
                size="large"
                variant="outlined"
                startIcon={<PhotoLibraryRounded />}
                onClick={() => fileInputRef.current?.click()}
              >
                Từ thư viện
              </Button>
            </Stack>
          </Box>
        ) : (
          <Stack spacing={2}>
            {imgUrl && (
              <Box
                sx={{
                  borderRadius: 2,
                  overflow: 'hidden',
                  maxHeight: 200,
                  bgcolor: 'action.hover',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                }}
              >
                <img
                  src={imgUrl}
                  alt="bill-chuyen-khoan"
                  style={{ maxWidth: '100%', maxHeight: 200, objectFit: 'contain' }}
                />
              </Box>
            )}
            {ocrLoading && (
              <Stack alignItems="center" spacing={1.5} sx={{ py: 2 }}>
                <CircularProgress />
                <Typography variant="body2" color="text.secondary">
                  Đang đọc số tiền và ngày…
                </Typography>
              </Stack>
            )}
            {error && (
              <Alert severity="error" icon={<WarningAmberRounded fontSize="small" />}>
                {error}
              </Alert>
            )}
            {!ocrLoading && !error && file && (
              <>
                <Alert severity="info" sx={{ '& .MuiAlert-message': { width: '100%' } }}>
                  <Typography fontWeight={800} sx={{ mb: 0.5 }}>
                    Đã đọc từ bill
                  </Typography>
                  <Row label="Số tiền" value={formatVnd(ocrAmount)} strong />
                  <Row label="Ngày" value={ocrDate ?? '—'} />
                  {(ocrAmount == null || ocrAmount <= 0) && (
                    <Typography variant="caption" color="error.main" sx={{ mt: 0.5, display: 'block' }}>
                      Không đọc được số tiền — nhập thủ công hoặc chọn ảnh rõ hơn.
                    </Typography>
                  )}
                  {ocrNeedsReview && ocrAmount != null && ocrAmount > 0 && (
                    <Typography variant="caption" color="warning.main" sx={{ mt: 0.5, display: 'block' }}>
                      Kiểm tra lại số tiền/ngày trước khi lưu.
                    </Typography>
                  )}
                </Alert>

                <Typography fontWeight={800}>Mô tả chuyển khoản</Typography>
                <Typography variant="body2" color="text.secondary">
                  Nhập nội dung để AI phân loại (vd: trà sữa, tiền điện, quà sinh nhật).
                </Typography>
                <TextField
                  fullWidth
                  multiline
                  minRows={2}
                  value={description}
                  onChange={(e) => setDescription(e.target.value)}
                  placeholder="Ví dụ: Tang em sinh nhật"
                  onKeyDown={(e) => {
                    if (e.key === 'Enter' && !e.shiftKey) {
                      e.preventDefault();
                      runClassify();
                    }
                  }}
                />
                <Button
                  variant="outlined"
                  startIcon={
                    classifyLoading ? (
                      <CircularProgress size={18} />
                    ) : (
                      <AutoAwesomeRounded />
                    )
                  }
                  disabled={classifyLoading}
                  onClick={runClassify}
                >
                  Phân loại với AI
                </Button>
                {classifyError && (
                  <Alert severity="error">{classifyError}</Alert>
                )}
                {classifyResult && (
                  <Alert severity="success" sx={{ '& .MuiAlert-message': { width: '100%' } }}>
                    <Typography fontWeight={800} sx={{ mb: 0.5 }}>
                      Kết quả phân loại
                    </Typography>
                    <Row
                      label="Loại"
                      value={
                        classifyResult.transactionType === 'INCOME' ? 'Thu nhập' : 'Chi tiêu'
                      }
                    />
                    <Row label="Danh mục" value={classifyResult.categoryName ?? '—'} />
                    <Row label="Mô tả" value={classifyResult.description ?? description} />
                  </Alert>
                )}
              </>
            )}
          </Stack>
        )}
      </DialogContent>
      <DialogActions sx={{ px: 3, py: 2 }}>
        {file && (
          <Button color="inherit" startIcon={<ReplayRounded />} onClick={reset}>
            Chọn ảnh khác
          </Button>
        )}
        <Button onClick={handleClose}>Hủy</Button>
        <Button variant="contained" disabled={!canApply} onClick={applyAndClose}>
          Dùng kết quả
        </Button>
      </DialogActions>
    </Dialog>
  );
}

function Row({ label, value, strong }: { label: string; value: string; strong?: boolean }) {
  return (
    <Stack direction="row" alignItems="baseline" spacing={1.5}>
      <Typography variant="body2" color="text.secondary" sx={{ width: 100, fontWeight: 600 }}>
        {label}
      </Typography>
      <Typography sx={{ fontWeight: strong ? 800 : 700, fontSize: strong ? 16 : 14, flex: 1 }}>
        {value}
      </Typography>
    </Stack>
  );
}

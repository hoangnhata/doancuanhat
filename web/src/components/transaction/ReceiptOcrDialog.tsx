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
  Typography,
} from '@mui/material';
import {
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
  const [result, setResult] = useState<OcrReceiptResult | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  function reset() {
    if (imgUrl) URL.revokeObjectURL(imgUrl);
    setImgUrl(null);
    setFile(null);
    setResult(null);
    setError(null);
    setLoading(false);
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
    setResult(null);
    setError(null);
    setLoading(true);
    try {
      const r = await transactionService.ocrReceipt(f);
      setResult(r);
    } catch (e) {
      setError(extractApiError(e));
    } finally {
      setLoading(false);
    }
  }

  function applyAndClose() {
    if (!result) return;
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
        <Box flex={1}>Quét hóa đơn</Box>
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
              Chọn ảnh hóa đơn (chụp bằng điện thoại hoặc từ thư viện). AI sẽ tự đọc số
              tiền, ngày và đề xuất danh mục.
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
            <Typography variant="caption" color="text.secondary" sx={{ mt: 2, display: 'block' }}>
              Hỗ trợ JPG/PNG, tối đa 10 MB.
            </Typography>
          </Box>
        ) : (
          <Stack spacing={2}>
            {imgUrl && (
              <Box
                sx={{
                  borderRadius: 2,
                  overflow: 'hidden',
                  maxHeight: 240,
                  bgcolor: 'action.hover',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                }}
              >
                <img
                  src={imgUrl}
                  alt="hoa-don"
                  style={{ maxWidth: '100%', maxHeight: 240, objectFit: 'contain' }}
                />
              </Box>
            )}
            {loading && (
              <Stack alignItems="center" spacing={1.5} sx={{ py: 2 }}>
                <CircularProgress />
                <Typography variant="body2" color="text.secondary">
                  Đang phân tích hóa đơn…
                </Typography>
              </Stack>
            )}
            {error && (
              <Alert severity="error" icon={<WarningAmberRounded fontSize="small" />}>
                {error}
              </Alert>
            )}
            {result && !loading && (
              <Box>
                {result.needsReview && (
                  <Alert severity="warning" sx={{ mb: 1.5 }} icon={<WarningAmberRounded fontSize="small" />}>
                    AI chưa chắc chắn — vui lòng kiểm tra lại trước khi lưu.
                  </Alert>
                )}
                <Stack spacing={0.5}>
                  <Row label="Số tiền" value={formatVnd(result.amount)} strong />
                  <Row label="Ngày" value={result.transactionDate ?? '—'} />
                  <Row label="Cửa hàng" value={result.merchant ?? '—'} />
                  <Row
                    label="Danh mục"
                    value={
                      (result.categoryName ?? '—') +
                      (result.categoryId == null ? ' (chọn lại sau khi áp dụng)' : '')
                    }
                  />
                  {result.confidence != null && (
                    <Row
                      label="Độ tin cậy"
                      value={`${Math.round(result.confidence * 100)}%`}
                    />
                  )}
                  <Row label="Engine" value={result.ocrEngine ?? '—'} />
                </Stack>
              </Box>
            )}
          </Stack>
        )}
      </DialogContent>
      <DialogActions sx={{ px: 3, py: 2 }}>
        {file && (
          <Button
            color="inherit"
            startIcon={<ReplayRounded />}
            onClick={() => {
              reset();
            }}
          >
            Chọn ảnh khác
          </Button>
        )}
        <Button onClick={handleClose}>Hủy</Button>
        <Button
          variant="contained"
          disabled={!result || result.amount == null || loading}
          onClick={applyAndClose}
        >
          Dùng kết quả này
        </Button>
      </DialogActions>
    </Dialog>
  );
}

function Row({ label, value, strong }: { label: string; value: string; strong?: boolean }) {
  return (
    <Stack direction="row" alignItems="baseline" spacing={1.5}>
      <Typography
        variant="body2"
        color="text.secondary"
        sx={{ width: 110, fontWeight: 600 }}
      >
        {label}
      </Typography>
      <Typography
        sx={{
          fontWeight: strong ? 800 : 700,
          fontSize: strong ? 16 : 14,
          flex: 1,
        }}
      >
        {value}
      </Typography>
    </Stack>
  );
}

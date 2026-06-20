import { AutoAwesomeRounded, DocumentScannerRounded } from '@mui/icons-material';
import {
  Button,
  Card,
  CardContent,
  CircularProgress,
  Stack,
  TextField,
  Typography,
} from '@mui/material';
import { palette } from '@/theme';

type Props = {
  value: string;
  onChange: (v: string) => void;
  onCategorize: () => void;
  onScanReceipt: () => void;
  isLoading: boolean;
  hidden?: boolean;
};

export function AiAssistCard({
  value,
  onChange,
  onCategorize,
  onScanReceipt,
  isLoading,
  hidden,
}: Props) {
  if (hidden) return null;

  return (
    <Card
      sx={{
        mb: 2,
        borderRadius: 4,
        overflow: 'hidden',
        border: `1px solid ${palette.primary.main}33`,
        boxShadow: palette.shadowLift,
        background: `linear-gradient(135deg, ${palette.primary.main}12 0%, #FFFFFF 60%)`,
      }}
    >
      <CardContent sx={{ p: { xs: 2, sm: 2.5 } }}>
        <Stack direction="row" alignItems="center" spacing={1} mb={1}>
          <AutoAwesomeRounded sx={{ color: palette.primary.main, fontSize: 20 }} />
          <Typography fontWeight={800} fontSize={15}>
            Nhập nhanh với AI
          </Typography>
        </Stack>
        <Typography variant="body2" color="text.secondary" mb={1.5}>
          Ví dụ: &quot;ăn trưa 50k&quot;, &quot;grab 30k + cà phê 45k&quot;
        </Typography>
        <TextField
          fullWidth
          placeholder="Mô tả tự nhiên..."
          value={value}
          onChange={(e) => onChange(e.target.value)}
          multiline
          minRows={2}
          sx={{
            mb: 1.5,
            '& .MuiOutlinedInput-root': { borderRadius: 3, bgcolor: '#fff' },
          }}
        />
        <Stack direction={{ xs: 'column', sm: 'row' }} spacing={1}>
          <Button
            variant="contained"
            startIcon={isLoading ? <CircularProgress size={16} color="inherit" /> : <AutoAwesomeRounded />}
            onClick={onCategorize}
            disabled={isLoading || !value.trim()}
            sx={{ borderRadius: 2, flex: 1 }}
          >
            {isLoading ? 'Đang phân loại…' : 'Phân loại AI'}
          </Button>
          <Button
            variant="outlined"
            startIcon={<DocumentScannerRounded />}
            onClick={onScanReceipt}
            sx={{ borderRadius: 2, flex: 1 }}
          >
            Quét hóa đơn
          </Button>
        </Stack>
      </CardContent>
    </Card>
  );
}

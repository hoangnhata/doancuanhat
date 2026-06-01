import { keyframes } from '@mui/material/styles';

/** Hiệu ứng nổi nhẹ — giống mascot app */
export const nattaFloat = keyframes`
  0%, 100% { transform: translateY(0); }
  50% { transform: translateY(-6px); }
`;

export const gentlePulse = keyframes`
  0%, 100% { opacity: 1; }
  50% { opacity: 0.85; }
`;

/** Tay vẫy chào (xoay quanh vai) */
export const robotArmWave = keyframes`
  0%, 100% { transform: rotate(-18deg); }
  50% { transform: rotate(22deg); }
`;

/** Đuôi lắc */
export const robotTailWiggle = keyframes`
  0%, 100% { transform: rotate(-6deg); }
  50% { transform: rotate(10deg); }
`;

/** Mắt chớp */
export const robotBlink = keyframes`
  0%, 45%, 55%, 100% { opacity: 1; }
  48%, 52% { opacity: 0.12; }
`;

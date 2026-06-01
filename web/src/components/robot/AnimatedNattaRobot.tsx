import { Box, type SxProps, type Theme } from '@mui/material';
import { useId } from 'react';
import {
  nattaFloat,
  robotArmWave,
  robotBlink,
  robotTailWiggle,
} from '@/theme/animations';
import { palette } from '@/theme';
import type { Personality } from '@/components/robot/types';

export type AnimatedNattaRobotProps = {
  size: number;
  personality?: Personality;
  isSelected?: boolean;
  animated?: boolean;
  alt?: string;
  sx?: SxProps<Theme>;
};

function accentFor(p?: Personality, selected?: boolean): string {
  if (!p) return palette.primary.light;
  switch (p) {
    case 'ANGRY':
      return selected ? '#FF6B6B' : '#FF8A80';
    case 'SAD':
      return selected ? '#9FA8DA' : '#B4B9F5';
    default:
      return selected ? '#6EC8FF' : palette.primary.light;
  }
}

/**
 * Robot Natta — phong cách chibi hiện đại: bo tròn mềm, gradient, mắt to dễ thương.
 */
export function AnimatedNattaRobot({
  size,
  personality = 'HAPPY',
  isSelected = false,
  animated = false,
  alt = 'Natta — trợ lý AI',
  sx,
}: AnimatedNattaRobotProps) {
  const uid = useId().replace(/:/g, '');
  const accent = accentFor(personality, isSelected);
  const glowSoft = isSelected ? `${accent}66` : `${accent}44`;
  const glowStrong = isSelected ? `${accent}99` : `${accent}55`;

  const h = size;
  const w = size * (100 / 128);
  const wave = animated ? `${robotArmWave} 1.1s cubic-bezier(0.45, 0, 0.55, 1) infinite` : 'none';
  const tailAnim = animated ? `${robotTailWiggle} 2.2s ease-in-out infinite` : 'none';
  const blink = animated ? `${robotBlink} 3.8s ease-in-out infinite` : 'none';
  const floatAnim = animated ? `${nattaFloat} 3.2s ease-in-out infinite` : 'none';

  return (
    <Box
      sx={{
        width: w,
        height: h,
        flexShrink: 0,
        animation: floatAnim,
        filter: `
          drop-shadow(0 2px 4px rgba(15, 23, 42, 0.06))
          drop-shadow(0 10px 24px ${glowSoft})
          drop-shadow(0 4px 12px ${glowStrong})
        `,
        ...sx,
      }}
      role="img"
      aria-label={alt}
    >
      <svg
        width={w}
        height={h}
        viewBox="0 0 100 128"
        fill="none"
        xmlns="http://www.w3.org/2000/svg"
        aria-hidden
      >
        <defs>
          <linearGradient id={`body-${uid}`} x1="20%" y1="0%" x2="80%" y2="100%">
            <stop offset="0%" stopColor="#FFFFFF" />
            <stop offset="45%" stopColor="#F8FAFC" />
            <stop offset="100%" stopColor="#EEF2F7" />
          </linearGradient>
          <linearGradient id={`head-${uid}`} x1="15%" y1="0%" x2="85%" y2="100%">
            <stop offset="0%" stopColor="#FFFFFF" />
            <stop offset="50%" stopColor="#FAFBFD" />
            <stop offset="100%" stopColor="#F1F5F9" />
          </linearGradient>
          <radialGradient id={`cheek-${uid}`} cx="50%" cy="50%" r="50%">
            <stop offset="0%" stopColor="#FDA4C4" stopOpacity={0.65} />
            <stop offset="100%" stopColor="#FDA4C4" stopOpacity={0} />
          </radialGradient>
          <linearGradient id={`screen-${uid}`} x1="50%" y1="0%" x2="50%" y2="100%">
            <stop offset="0%" stopColor="#0F2744" />
            <stop offset="55%" stopColor="#0A1628" />
            <stop offset="100%" stopColor="#060d18" />
          </linearGradient>
          <linearGradient id={`screenShine-${uid}`} x1="50%" y1="0%" x2="50%" y2="100%">
            <stop offset="0%" stopColor="#38BDF8" stopOpacity={0.22} />
            <stop offset="40%" stopColor="#38BDF8" stopOpacity={0} />
            <stop offset="100%" stopColor="#000" stopOpacity={0} />
          </linearGradient>
          <linearGradient id={`tail-${uid}`} x1="0%" y1="50%" x2="100%" y2="50%">
            <stop offset="0%" stopColor={accent} stopOpacity={0.95} />
            <stop offset="100%" stopColor={accent} stopOpacity={0.55} />
          </linearGradient>
          <linearGradient id={`earIn-${uid}`} x1="50%" y1="0%" x2="50%" y2="100%">
            <stop offset="0%" stopColor="#FFD6E8" />
            <stop offset="100%" stopColor="#FFB8D9" />
          </linearGradient>
        </defs>

        {/* Đuôi — cong mềm, có fill nhẹ */}
        <g
          style={{
            transformOrigin: '80px 88px',
            animation: tailAnim,
          }}
        >
          <path
            d="M 79 87 C 88 82 94 72 96 60 C 97 52 95 44 91 40"
            stroke={`url(#tail-${uid})`}
            strokeWidth="4"
            strokeLinecap="round"
            fill="none"
          />
          <circle cx="91" cy="40" r="3.5" fill={accent} opacity={0.85} />
        </g>

        {/* Chân — boot tròn, chunky */}
        <ellipse cx="41" cy="121" rx="11" ry="5" fill="rgba(15,23,42,0.08)" />
        <ellipse cx="59" cy="121" rx="11" ry="5" fill="rgba(15,23,42,0.08)" />
        <path
          d="M 30 98 L 30 112 Q 30 118 41 118 Q 48 118 48 112 L 48 98 Q 41 96 30 98 Z"
          fill={`url(#body-${uid})`}
          stroke="#E2E8F0"
          strokeWidth="0.6"
        />
        <path
          d="M 52 98 L 52 112 Q 52 118 59 118 Q 70 118 70 112 L 70 98 Q 59 96 52 98 Z"
          fill={`url(#body-${uid})`}
          stroke="#E2E8F0"
          strokeWidth="0.6"
        />
        <ellipse cx="41" cy="114" rx="5" ry="2.5" fill={accent} opacity={0.35} />
        <ellipse cx="59" cy="114" rx="5" ry="2.5" fill={accent} opacity={0.35} />

        {/* Thân — hình đậu mềm */}
        <path
          d="M 50 52 C 28 52 18 68 18 78 C 18 92 32 102 50 102 C 68 102 82 92 82 78 C 82 66 72 52 50 52 Z"
          fill={`url(#body-${uid})`}
          stroke="#E2E8F0"
          strokeWidth="0.7"
        />
        <ellipse cx="50" cy="72" rx="20" ry="2.5" fill="none" stroke={accent} strokeWidth="0.9" opacity={0.35} />

        {/* Tay trái + bàn tay tròn */}
        <path
          d="M 24 58 C 14 64 10 76 11 86"
          stroke="#F1F5F9"
          strokeWidth="11"
          strokeLinecap="round"
          fill="none"
        />
        <path
          d="M 24 58 C 14 64 10 76 11 86"
          stroke={accent}
          strokeWidth="1.4"
          strokeLinecap="round"
          fill="none"
          opacity={0.4}
        />
        <circle cx="11" cy="88" r="5" fill={`url(#body-${uid})`} stroke="#E2E8F0" strokeWidth="0.5" />

        {/* Tay phải — vẫy */}
        <g
          style={{
            transformOrigin: '76px 56px',
            animation: wave,
          }}
        >
          <path
            d="M 76 56 C 86 52 92 62 93 72 C 94 82 90 90 85 94"
            stroke="#F1F5F9"
            strokeWidth="11"
            strokeLinecap="round"
            fill="none"
          />
          <path
            d="M 76 56 C 86 52 92 62 93 72"
            stroke={accent}
            strokeWidth="1.4"
            strokeLinecap="round"
            fill="none"
            opacity={0.4}
          />
          <circle cx="85" cy="95" r="5" fill={`url(#body-${uid})`} stroke="#E2E8F0" strokeWidth="0.5" />
        </g>

        {/* Cổ */}
        <rect x="43" y="48" width="14" height="11" rx="5" fill="#F1F5F9" stroke="#E2E8F0" strokeWidth="0.5" />

        {/* Tai mèo — bo mềm hơn */}
        <path
          d="M 26 24 Q 22 10 28 6 Q 34 4 38 16 Z"
          fill={`url(#head-${uid})`}
          stroke="#E2E8F0"
          strokeWidth="0.55"
          strokeLinejoin="round"
        />
        <path
          d="M 32 14 Q 30 10 33 9 Q 36 10 35 14 Z"
          fill={`url(#earIn-${uid})`}
          opacity={0.95}
        />
        <path
          d="M 74 24 Q 78 10 72 6 Q 66 4 62 16 Z"
          fill={`url(#head-${uid})`}
          stroke="#E2E8F0"
          strokeWidth="0.55"
          strokeLinejoin="round"
        />
        <path
          d="M 68 14 Q 70 10 67 9 Q 64 10 65 14 Z"
          fill={`url(#earIn-${uid})`}
          opacity={0.95}
        />

        {/* Đầu — bo siêu tròn */}
        <rect
          x="18"
          y="12"
          width="64"
          height="50"
          rx="16"
          fill={`url(#head-${uid})`}
          stroke="#E2E8F0"
          strokeWidth="0.75"
        />
        {/* Viền highlight nhẹ */}
        <rect
          x="19"
          y="13"
          width="62"
          height="48"
          rx="15"
          fill="none"
          stroke="rgba(255,255,255,0.85)"
          strokeWidth="0.6"
          opacity={0.9}
        />

        {/* Màn hình OLED */}
        <rect
          x="23"
          y="26"
          width="54"
          height="30"
          rx="8"
          fill={`url(#screen-${uid})`}
          stroke="#1e3a5f"
          strokeWidth="0.5"
        />
        <rect
          x="23"
          y="26"
          width="54"
          height="14"
          rx="8"
          fill={`url(#screenShine-${uid})`}
        />

        <Face personality={personality} accent={accent} blink={blink} uid={uid} />

        {/* Viền accent — mảnh, hiện đại */}
        <rect
          x="18"
          y="12"
          width="64"
          height="50"
          rx="16"
          fill="none"
          stroke={accent}
          strokeWidth={isSelected ? 1.6 : 1}
          opacity={isSelected ? 0.55 : 0.28}
        />
      </svg>
    </Box>
  );
}

function Face({
  personality,
  accent,
  blink,
  uid,
}: {
  personality: Personality;
  accent: string;
  blink: string;
  uid: string;
}) {
  const eyeCore = '#5EEAD4';
  const eyeGlow = '#99F6E4';
  const cheek = `url(#cheek-${uid})`;

  if (personality === 'ANGRY') {
    return (
      <g>
        <path
          d="M 32 34 L 40 38"
          stroke="#FCA5A5"
          strokeWidth="2.2"
          strokeLinecap="round"
        />
        <path
          d="M 68 34 L 60 38"
          stroke="#FCA5A5"
          strokeWidth="2.2"
          strokeLinecap="round"
        />
        <ellipse cx="37" cy="42" rx="4" ry="5" fill="#FB7185" transform="rotate(12 37 42)" />
        <ellipse cx="63" cy="42" rx="4" ry="5" fill="#FB7185" transform="rotate(-12 63 42)" />
        <path
          d="M 45 51 Q 50 47 55 51"
          stroke="#FB7185"
          strokeWidth="2"
          fill="none"
          strokeLinecap="round"
        />
      </g>
    );
  }

  if (personality === 'SAD') {
    return (
      <g>
        <path
          d="M 36 41 Q 38 39 40 41"
          stroke={eyeGlow}
          strokeWidth="2.4"
          fill="none"
          strokeLinecap="round"
        />
        <path
          d="M 60 41 Q 62 39 64 41"
          stroke={eyeGlow}
          strokeWidth="2.4"
          fill="none"
          strokeLinecap="round"
        />
        <path
          d="M 43 51 Q 50 48 57 51"
          stroke={accent}
          strokeWidth="1.6"
          fill="none"
          strokeLinecap="round"
        />
        <circle cx="33" cy="44" r="5" fill={cheek} />
        <circle cx="67" cy="44" r="5" fill={cheek} />
      </g>
    );
  }

  /* HAPPY — mắt to, highlight kép, miệng cười mềm */
  return (
    <g>
      <g style={{ animation: blink }}>
        <ellipse cx="38" cy="40" rx="5.2" ry="5.8" fill={eyeCore} />
        <ellipse cx="62" cy="40" rx="5.2" ry="5.8" fill={eyeCore} />
        <ellipse cx="39.5" cy="38.2" rx="1.8" ry="2" fill="#fff" opacity={0.95} />
        <ellipse cx="63.5" cy="38.2" rx="1.8" ry="2" fill="#fff" opacity={0.95} />
        <circle cx="36.8" cy="41.5" r="1" fill="#134E4A" opacity={0.35} />
        <circle cx="60.8" cy="41.5" r="1" fill="#134E4A" opacity={0.35} />
      </g>
      <path
        d="M 43 52 Q 50 58.5 57 52"
        stroke={eyeGlow}
        strokeWidth="2.4"
        fill="none"
        strokeLinecap="round"
      />
      <circle cx="31" cy="45" r="6.5" fill={cheek} />
      <circle cx="69" cy="45" r="6.5" fill={cheek} />
      <path
        d="M 33 34 C 31 32 29 33 28 35"
        stroke={eyeGlow}
        strokeWidth="1"
        fill="none"
        strokeLinecap="round"
        opacity={0.65}
      />
      <path
        d="M 67 34 C 69 32 71 33 72 35"
        stroke={eyeGlow}
        strokeWidth="1"
        fill="none"
        strokeLinecap="round"
        opacity={0.65}
      />
    </g>
  );
}

import * as React from 'react';
import * as TooltipPrimitive from '@radix-ui/react-tooltip';

function TooltipProvider({ delayDuration = 0, ...props }) {
  return (
    <TooltipPrimitive.Provider
      data-slot="tooltip-provider"
      delayDuration={delayDuration}
      {...props}
    />
  );
}

function Tooltip({ ...props }) {
  return (
    <TooltipProvider>
      <TooltipPrimitive.Root data-slot="tooltip" {...props} />
    </TooltipProvider>
  );
}

function TooltipTrigger({ ...props }) {
  return <TooltipPrimitive.Trigger data-slot="tooltip-trigger" {...props} />;
}

const ARROW_STYLES = {
  top: {
    bottom: 0,
    left: '50%',
    transform: 'translateX(-50%) translateY(50%) rotate(45deg)',
    borderTop: 'none',
    borderLeft: 'none',
  },
  bottom: {
    top: 0,
    left: '50%',
    transform: 'translateX(-50%) translateY(-50%) rotate(45deg)',
    borderBottom: 'none',
    borderRight: 'none',
  },
  left: {
    right: 0,
    top: '50%',
    transform: 'translateY(-50%) translateX(50%) rotate(45deg)',
    borderLeft: 'none',
    borderTop: 'none',
  },
  right: {
    left: 0,
    top: '50%',
    transform: 'translateY(-50%) translateX(-50%) rotate(45deg)',
    borderRight: 'none',
    borderBottom: 'none',
  },
};

function TooltipContent({ className = '', sideOffset = 8, side = 'top', children, ...props }) {
  const arrow = ARROW_STYLES[side] || ARROW_STYLES.top;
  return (
    <TooltipPrimitive.Portal>
      <TooltipPrimitive.Content
        data-slot="tooltip-content"
        sideOffset={sideOffset}
        side={side}
        className={['relative z-[9999] max-w-[220px] rounded-lg border border-gray-200 bg-white px-2.5 py-2 text-xs text-gray-600 shadow-lg', className].join(' ')}
        {...props}
      >
        {children}
        <span
          aria-hidden
          style={{
            pointerEvents: 'none',
            position: 'absolute',
            zIndex: 10000,
            width: 10,
            height: 10,
            backgroundColor: '#fff',
            border: '1px solid #e5e7eb',
            ...arrow,
          }}
        />
      </TooltipPrimitive.Content>
    </TooltipPrimitive.Portal>
  );
}

export { Tooltip, TooltipTrigger, TooltipContent, TooltipProvider };

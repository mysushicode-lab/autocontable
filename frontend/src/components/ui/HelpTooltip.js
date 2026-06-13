import React from 'react';
import { Tooltip, TooltipTrigger, TooltipContent } from './tooltip';

export default function HelpTooltip({ text, side = 'top' }) {
  return (
    <Tooltip>
      <TooltipTrigger asChild>
        <div className="w-3.5 h-3.5 rounded-full bg-gray-200 flex items-center justify-center cursor-help shrink-0">
          <span className="text-[9px] text-gray-500 font-medium leading-none select-none">?</span>
        </div>
      </TooltipTrigger>
      <TooltipContent side={side} sideOffset={6}>
        {text}
      </TooltipContent>
    </Tooltip>
  );
}

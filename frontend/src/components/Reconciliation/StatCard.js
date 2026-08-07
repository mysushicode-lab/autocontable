import React from 'react';
import IconBox from '../ui/IconBox';

const StatCard = ({ title, value, icon: Icon, color, period }) => {
  return (
    <div className="p-5">
      <IconBox color={color} size="sm" className="inline-flex mb-3">
        <Icon className="w-3.5 h-3.5" />
      </IconBox>

      <div className="flex items-center justify-between mb-3">
        <p className="text-xs font-medium text-gray-600">{title}</p>
        {period && <span className="text-[10px] text-gray-400">{period}</span>}
      </div>

      <p className="text-3xl font-bold text-gray-900">{value}</p>
    </div>
  );
};

export default StatCard;

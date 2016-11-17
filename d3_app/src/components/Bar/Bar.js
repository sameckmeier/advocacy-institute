import React from 'react';
import './Bar.scss';

const Bar = ({
  x,
  y,
  width,
  height
}) => {
  return (
    <rect className="Bar" x={x} y={y} width={width} height={height} />
  );
}

export default Bar;

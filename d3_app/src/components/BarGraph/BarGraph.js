import React from 'react';
import * as d3 from 'd3';
import Bar from '../Bar';
import Axis from '../Axis';

const BarGraph = ({ vertices }) => {
  const margin = {top: 20, right: 20, bottom: 20, left: 40};
  const height = 500;
  const width = 700;

  let xAxis = {};
  let yAxis = {};

  let xScale = null;
  let yScale = null;

  let xRange = 0;
  let yRange = 0;

  if (vertices.length > 0) {
    const yMax = d3.max(vertices, vertice => vertice.y);

    yRange = height - margin.top - margin.bottom;
    yScale = d3.scaleLinear()
      .range([yRange, 0])
      .domain([0, yMax]);

    yAxis = {
      orient: 'left',
      scale: yScale,
      ticks: yMax,
    };

    xRange = width - margin.left - margin.right;
    xScale = d3.scaleBand()
      .range([0, xRange])
      .padding(0.1)
      .domain(vertices.map(vertice => vertice.x));

    xAxis = {
      orient: 'bottom',
      translate: `translate(0, ${yRange})`,
      scale: xScale,
    };
  }

  return (
    <svg width={width} height={height}>
      <g transform={`translate(${margin.left},${margin.top})`}>
        {
          vertices.map( (vertice, i) => {
            const props = {
              key: i,
              x: xScale(vertice.x),
              y: yScale(vertice.y),
              width: xScale.bandwidth(),
              height: yRange - yScale(vertice.y),
            };

            return <Bar {...props} />;
          })
        }

        <Axis {...yAxis} />
        <Axis {...xAxis} />
      </g>
    </svg>
  );
}

export default BarGraph;

import React, { Component } from 'react';
import * as d3 from 'd3';

export default class Axis extends Component {
  componentDidMount() {
    this.renderAxis();
  }

  componentDidUpdate() {
    this.renderAxis();
  }

  renderAxis() {
    const { orient, scale, ticks } = this.props;

    if (orient) {
      const axisWrapper  = this.refs.axisWrapper;

      const axis = orient === 'bottom' ? d3.axisBottom(scale) : d3.axisLeft(scale);
      if (ticks) { axis.ticks(ticks) }

      d3.select(axisWrapper).call(axis);
    }
  }

  render() {
    return (
      <g className="Axis" ref="axisWrapper" transform={this.props.translate}></g>
    );
  }
}

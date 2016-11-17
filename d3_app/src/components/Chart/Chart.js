import React, { Component } from 'react';
import BarGraph from '../BarGraph';
import PodioApi, { fieldsByType, d3Format } from '../../utilities/podio';
import './Chart.scss';

export default class Chart extends Component {
  constructor(props) {
    super(props);
    this.state = {
      data: [],
      displayedDataIndex: 0,
    };
  }

  componentDidMount() {
    PodioApi.meetingsAppData((error, response, body) => {
      const req_data = JSON.parse(body);
      const fields = fieldsByType(req_data.items, 'category');
      const data = d3Format(fields);

      this.setState({ data })
    });
  }

  toggleData(index) {
    this.setState({
      displayedDataIndex: index,
    })
  }

  render() {
    const { displayedDataIndex, data } = this.state
    const fieldNames = data.map(obj => obj.fieldName);
    const vertices = data[displayedDataIndex] ? data[displayedDataIndex].vertices : [];

    return (
      <div className="Chart">
        <BarGraph vertices={vertices}/>
        <div className="Chart-data-toggles">
          {
            fieldNames.map((fieldName, i) => {
              return (
                <button
                  key={i}
                  className='Chart-data-toggle'
                  onClick={this.toggleData.bind(this, i)}
                >
                  {fieldName}
                </button>
              );
            })
          }
        </div>
      </div>
    );
  }
}

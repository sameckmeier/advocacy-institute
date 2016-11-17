import request from 'request';
import qs from 'querystring';

class PodioApi {
  constructor(args) {
    this.baseUri = 'https://api.podio.com';
  }

  _authenticatedRequest(options, callback) {
    const queryString = qs.stringify({
      username: process.env.email,
      password: process.env.password,
      client_id: process.env.clientId,
      client_secret: process.env.clientSecret,
      grant_type: 'password',
    });

    const authOptions = {
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Accept': 'application/x-www-form-urlencoded',
      },
      method: 'POST',
      uri: `${this.baseUri}/oauth/token?${queryString}`,
    };

    request(authOptions, (error, response, body) => {
      const req_data = JSON.parse(body);

      options.headers = Object.assign(options.headers, {
        'Authorization': `OAuth2 ${req_data.access_token}`,
      });

      request(options, callback);
    });
  }

  meetingsAppData(callback) {
    const slug = `item/app/${process.env.podioAppId}`

    const options = {
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      method: 'GET',
      uri: `${this.baseUri}/${slug}`,
    };

    this._authenticatedRequest(options, callback);
  }
}

export const fieldsByType = (items, type) => {
  const filteredFields = [];

  let fields = [];
  items.forEach(item => fields = fields.concat(...item.fields))
  fields.forEach(field => {
    if (field.type === type) {  filteredFields.push(field) }
  })

  return filteredFields;
};

const mapVertices = fields => {
  const mapped = {};
  let index = fields.length - 1;

  while (index >= 0) {
    const field = fields[index];
    const label = field.label;
    const value = field.values[0].value.text;

    if (mapped[label]) {
      if (mapped[label][value] === undefined) {
        mapped[label][value] = 1;
      } else {
        mapped[label][value] += 1;
      }
    } else {
      mapped[label] = {};
      mapped[label][value] = 1;
    }

    index -= 1;
  }

  return mapped;
};

export const d3Format = vertices => {
  const formatted = [];
  const mappedVertices = mapVertices(vertices);

  Object.keys(mappedVertices).forEach ( mappedVerticeLabel => {
    const d3GraphData = {
      fieldName: mappedVerticeLabel,
      vertices: [],
    };

    const xYValues = mappedVertices[mappedVerticeLabel];
    Object.keys(xYValues).forEach( xYValue => {
      d3GraphData.vertices.push({
        x: xYValue,
        y: xYValues[xYValue],
      })
    })

    formatted.push(d3GraphData);
  })

  return formatted;
}

export default new PodioApi();

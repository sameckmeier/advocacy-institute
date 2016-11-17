import React from 'react';
import logo from '../../assets/AI-Logo.png';
import './Header.scss';

const Header = () => {
  return (
    <div className="Header">
      <div className="Header-top">
        <div className="Header-logo-wrapper">
          <a href='http://hi.advocacy-institute.org/'>
            <img src={logo} alt='logo'/>
          </a>
        </div>
      </div>
      <div className="Header-bottom">
        <div className="Header-title-wrapper">
          <h1>Meetings App Visualization</h1>
        </div>
      </div>
    </div>
  );
};

export default Header;

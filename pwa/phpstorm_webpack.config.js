/**
 * THIS FILE IS FOR PHPSTORM SO THAT IT MAPS THE TILDE (~) PREFIX CORRECTLY - YOU CAN SET THIS AS THE WEBPACK FILE IN PREFERENCES
 */
const path = require('path')

module.exports = {
  resolve: {
    extensions: ['.js', '.json', '.vue'],
    alias: {
      '~': path.resolve(__dirname, './')
    }
  }
}

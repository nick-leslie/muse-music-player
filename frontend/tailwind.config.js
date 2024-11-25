module.exports = {
  content: ["./index.html", "./src/**/*.{gleam,mjs}"],
  theme: {
    extend: {
      colors: {
        'eerie-black': {
          DEFAULT: '#1d1d1d',
          100: '#060606',
          200: '#0b0b0b',
          300: '#111111',
          400: '#161616',
          500: '#1d1d1d',
          600: '#494949',
          700: '#777777',
          800: '#a4a4a4',
          900: '#d2d2d2'
        },
        'licorice': {
          DEFAULT:
          '#362023',
          100: '#0b0607',
          200: '#160d0e',
          300: '#211315',
          400: '#2c1a1c',
          500: '#362023',
          600: '#6c3f45',
          700: '#a15f68',
          800: '#c0949a',
          900: '#e0cacd'
        },
        'tea-rose-(red)': {
          DEFAULT: '#dbb3b1',
          100: '#361b19',
          200: '#6d3532',
          300: '#a3504b',
          400: '#c37f7c',
          500: '#dbb3b1',
          600: '#e3c3c2',
          700: '#ead2d1',
          800: '#f1e1e0',
          900: '#f8f0f0'
        }, 'rosy_brown': {
          DEFAULT: '#c89fa3',
          100: '#2d1a1c',
          200: '#5b3438',
          300: '#884e54',
          400: '#ad7177',
          500: '#c89fa3',
          600: '#d2b1b5',
          700: '#ddc5c7',
          800: '#e9d8da',
          900: '#f4ecec'
        }, 'pomp-and-power': {
          DEFAULT: '#9e6393',
          100: '#1f141d',
          200: '#3f273a',
          300: '#5e3b58',
          400: '#7d4f75',
          500: '#9e6393',
          600: '#b082a8',
          700: '#c4a1be',
          800: '#d8c0d3',
          900: '#ebe0e9' }
      },
      fontFamily: {
        "forum": ['forum ', 'sans-serif'],
        "quicksand": ['quicksand ', 'sans-serif'],
      }
    },
  },
  plugins: [],
};

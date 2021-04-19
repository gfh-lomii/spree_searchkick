// Placeholder manifest file.
// the installer will append this file to the app vendored assets here: vendor/assets/javascripts/spree/frontend/all.js'
//= require_tree .

var normalize = function (input) {
  if (!input) return ''
  return input.normalize("NFD").replace(/[\u0300-\u036f]/g, "").toLowerCase();
};

var queryTokenizer = function (q) {
  var normalized = normalize(q);
  return Bloodhound.tokenizers.whitespace(normalized);
};

var transformObj = function (obj) {
  return obj['n'] + ' ' + obj['p'] + ' ' + obj['t'] + ' ' + obj['k'];
};

var formatSearchResponse = function (response) {
  return $.map(response, function (obj) {
    var normalized = normalize(transformObj(obj));
    return {
      value: normalized,
      displayValue: obj['n']
    };
  });
};

Spree.typeaheadSearch = function () {
  var products = new Bloodhound({

    datumTokenizer: Bloodhound.tokenizers.obj.whitespace('value'),
    queryTokenizer: queryTokenizer,
    prefetch: {
      url: Spree.pathFor('autocomplete/products.json'),
      ttl: 14400000,
      transform: function (response) {
        return formatSearchResponse(response);
      }
    },
    remote: {
      url: Spree.pathFor('autocomplete/products.json?keywords=%25QUERY'),
      wildcard: '%QUERY',
      transform: function (response) {
        return formatSearchResponse(response);
      }
    }
  });
  products.initialize();
  // passing in `null` for the `options` arguments will result in the default
  // options being used
  $('#keywords').typeahead({
    minLength: 1,
    hint: false,
    highlight: true
  }, {

    displayKey: 'displayValue',
    limit: 10,
    name: 'products',
    source: products.ttAdapter(),
  });
};

document.addEventListener("turbolinks:load", function () {
  if (typeof Spree.typeaheadSearch !== 'undefined') Spree.typeaheadSearch();
});
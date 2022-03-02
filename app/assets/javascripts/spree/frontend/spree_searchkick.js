// Placeholder manifest file.
// the installer will append this file to the app vendored assets here: vendor/assets/javascripts/spree/frontend/all.js'
//= require_tree .

var normalize2 = function (input) {
  if(!input) return ''
  return input.normalize("NFD").replace(/[\u0300-\u036f]/g, "").toLowerCase();
};

var queryTokenizer = function (q) {
  var normalized = normalize2(q);
  return Bloodhound.tokenizers.whitespace(normalized);
};

var transformObj = function (obj) {
  return obj['n'] + ' ' + obj['p'] + ' ' + obj['t'] + ' ' + obj['k'];
};

var formatSearchResponse = function (response) {
  return $.map(response, function (obj) {
    var normalized = normalize2(transformObj(obj));
    return {
      value: normalized,
      displayValue: obj['n'],
      displayObj: obj
    };
  });
};

var configImgCdn = function (img_url, width, height, quality) {
  if ($('body').attr('data-rails-env') === 'development') return img_url;
  var splitUrl = img_url.split('/')
  return splitUrl[0] + '//' + splitUrl[2] + '/' + 'cdn-cgi/image/width=' + width + ',height=' + height + ',quality=' + quality + ',f=auto,fit=pad/' + splitUrl[3];
};

Spree.typeaheadSearch = function () {
  const stockLocationParam =  '?stock_locations=' + Spree.stockLocations();
  var products = new Bloodhound({
    // datumTokenizer: Bloodhound.tokenizers.obj.whitespace('value'),
    // queryTokenizer: queryTokenizer,
    datumTokenizer: function(d) {
      return Bloodhound.tokenizers.whitespace(d.value);
    },
    queryTokenizer: queryTokenizer,
    prefetch: {
      url: Spree.pathFor('autocomplete/products.json') + stockLocationParam,
      ttl: 14400000,
      transform: function (response) {
        return formatSearchResponse(response);
      }
    }
    // ,
    // remote: {
    //   url: Spree.pathFor('autocomplete/products.json?keywords=%25QUERY') + '&stock_locations=' + stockLocationParam.replace('?', '&'),
    //   wildcard: '%QUERY',
    //   transform: function (response) {
    //     return formatSearchResponse(response);
    //   }
    // }
  });

  products.initialize().done(function () {
    setTimeout(function () {
      $('#search_loader').addClass('d-none').removeClass('load');
    }, 0);
  });

  // passing in `null` for the `options` arguments will result in the default
  // options being used
  $('#keywords').typeahead({
    minLength: 1,
    hint: false,
    highlight: true
  },{
    display: 'value',
    limit: 20,
    name: 'products',
    source: products.ttAdapter(),
    templates: {
      empty: 'No se encontraron los productos que estás buscando',
      suggestion: function (el) {
        var obj = el.displayObj
        return '<div><img class="lazyload"  alt="  ' + obj.n + ' " data-src="' + configImgCdn(obj.i, 50, 50, 75) + '"  width="50" height="50" style="border-radius: 10px; margin-right: 10px; height: auto"/>' + obj.n + '<br>' +  obj.p + '</div>'
      }
    }
  });
};

document.addEventListener("turbolinks:load", function () {
  if ($("#search-button-kick")){
    $(document).on("click", "#search-button-kick", function () {
      if($('#search_loader').hasClass('load')){
        Spree.typeaheadSearch();
      }
    });
  }
});

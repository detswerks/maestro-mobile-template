// data/search-data.js
// Test data fixtures for article search and saving flows (environment-aware via APP_ENV)

(function () {
  var envData = {
    staging: {
      query: "software testing",
      expectedArticleTitle: "Software testing",
      expectedArticleRegex: "^Software testing$",
      noResultsQuery: "xyznonexistentarticle99999",
      nonExistentSavedArticle: "NonExistent Demo Article XYZ"
    },
    production: {
      query: "software testing",
      expectedArticleTitle: "Software testing",
      expectedArticleRegex: "^Software testing$",
      noResultsQuery: "xyznonexistentarticle99999",
      nonExistentSavedArticle: "NonExistent Demo Article XYZ"
    }
  };

  var activeEnv = (typeof APP_ENV !== "undefined" && envData[APP_ENV]) ? APP_ENV : "staging";
  output.searchData = envData[activeEnv];
})();

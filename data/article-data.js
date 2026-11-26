// data/article-data.js
// Test data fixtures for article theme and multi-tab browsing flows (environment-aware via APP_ENV)

(function () {
  var envData = {
    staging: {
      firstQuery: "software testing",
      firstArticleRegex: "^Software testing$",
      secondQuery: "unit testing",
      secondArticleRegex: "^Unit testing$",
      defaultTextSizeLabel: "100% (Default)",
      expectedTwoTabsCount: "2"
    },
    production: {
      firstQuery: "software testing",
      firstArticleRegex: "^Software testing$",
      secondQuery: "unit testing",
      secondArticleRegex: "^Unit testing$",
      defaultTextSizeLabel: "100% (Default)",
      expectedTwoTabsCount: "2"
    }
  };

  var activeEnv = (typeof APP_ENV !== "undefined" && envData[APP_ENV]) ? APP_ENV : "staging";
  output.articleData = envData[activeEnv];
})();

// data/reading-list-data.js
// Test data fixtures for complex multi-article research & reading list workflow (environment-aware via APP_ENV)

(function () {
  var envData = {
    staging: {
      primaryQuery: "software testing",
      primaryArticleTitle: "Software testing",
      primaryArticleRegex: "^Software testing$",
      findKeyword: "testing",
      tocSection: "History",
      readingListName: "QA Research",
      readingListDescription: "Automated E2E test reading list",
      secondaryQuery: "unit testing",
      secondaryArticleTitle: "Unit testing",
      secondaryArticleRegex: "^Unit testing$",
      filterKeyword: "Unit"
    },
    production: {
      primaryQuery: "software testing",
      primaryArticleTitle: "Software testing",
      primaryArticleRegex: "^Software testing$",
      findKeyword: "testing",
      tocSection: "History",
      readingListName: "QA Research",
      readingListDescription: "Automated E2E test reading list",
      secondaryQuery: "unit testing",
      secondaryArticleTitle: "Unit testing",
      secondaryArticleRegex: "^Unit testing$",
      filterKeyword: "Unit"
    }
  };

  var activeEnv = (typeof APP_ENV !== "undefined" && envData[APP_ENV]) ? APP_ENV : "staging";
  output.readingListData = envData[activeEnv];
})();

// data/onboarding-data.js
// Test data fixtures for onboarding flows (environment-aware via APP_ENV)

(function () {
  var envData = {
    staging: {
      interestTopic: "Art"
    },
    production: {
      interestTopic: "Art"
    }
  };

  var activeEnv = (typeof APP_ENV !== "undefined" && envData[APP_ENV]) ? APP_ENV : "staging";
  output.onboardingData = envData[activeEnv];
})();

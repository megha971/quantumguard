// backend/src/services/creditScore.js
const SCORE_WEIGHTS = {
  loan_repaid:  40,
  loan_default: -100,
  loan_taken:   -5,
  crop_sale:    20,
  land_verified: 30,
};

const MAX_SCORE = 850;
const MIN_SCORE = 300;
const BASE_SCORE = 500;

const recalculate = (events = []) => {
  let score = BASE_SCORE;
  const sorted = [...events].sort((a, b) => new Date(a.date) - new Date(b.date));
  for (const event of sorted) {
    const weight = SCORE_WEIGHTS[event.type] || 0;
    if (event.type === 'loan_repaid' && event.amount) {
      const bonus = Math.min(Math.floor(event.amount / 10000), 20);
      score += weight + bonus;
    } else if (event.type === 'crop_sale' && event.amount) {
      const bonus = Math.min(Math.floor(event.amount / 5000), 10);
      score += weight + bonus;
    } else {
      score += weight;
    }
  }
  return Math.max(MIN_SCORE, Math.min(MAX_SCORE, Math.round(score)));
};

const getScoreCategory = (score) => {
  if (score >= 750) return { label: 'Excellent', color: 'green' };
  if (score >= 650) return { label: 'Good', color: 'blue' };
  if (score >= 550) return { label: 'Fair', color: 'yellow' };
  if (score >= 450) return { label: 'Poor', color: 'orange' };
  return { label: 'Very Poor', color: 'red' };
};

module.exports = { recalculate, getScoreCategory };

import { onCLS, onINP, onLCP, onFCP, onTTFB } from 'web-vitals';

const ANALYTICS_ID = import.meta.env.VITE_GA_MEASUREMENT_ID;

const sendToAnalytics = ({ name, value, id }) => {
  if (!ANALYTICS_ID || typeof window.gtag !== 'function') {
    return;
  }

  window.gtag('event', name, {
    value: Math.round(name === 'CLS' ? value * 1000 : value),
    metric_id: id,
    metric_value: value,
    metric_delta: value,
    non_interaction: true,
  });
};

export default function reportWebVitals() {
  onCLS(sendToAnalytics);
  onINP(sendToAnalytics);
  onLCP(sendToAnalytics);
  onFCP(sendToAnalytics);
  onTTFB(sendToAnalytics);
}

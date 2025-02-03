import { BrowserRouter } from 'react-router-dom';
import { SupabaseProvider } from './contexts/SupabaseContext'; 
import AppContent from './components/common/AppContent';
function App() {
  return (
    <BrowserRouter>
      <SupabaseProvider>
        <AppContent />
      </SupabaseProvider>
    </BrowserRouter>
  );
}

export default App;
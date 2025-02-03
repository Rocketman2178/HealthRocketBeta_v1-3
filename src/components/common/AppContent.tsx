import { AuthGuard } from "../auth/AuthGuard";
import { AppRoutes } from "../../routes";
import { RootLayout } from "../ui/space-background";

function AppContent() {

  
    return (
      <AuthGuard>
        <RootLayout>
          <AppRoutes />
        </RootLayout>
      </AuthGuard>
    );
  }

  export default AppContent;
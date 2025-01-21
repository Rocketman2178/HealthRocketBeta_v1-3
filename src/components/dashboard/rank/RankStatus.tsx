import { CommunityLeaderboard } from './CommunityLeaderboard';
import { useCommunity } from '../../../hooks/useCommunity';
import { useSupabase } from '../../../contexts/SupabaseContext';
export function RankStatus() {
  const { user } = useSupabase();
  const { primaryCommunity, loading: communityLoading } = useCommunity(user?.id);

  return (
    <div className="space-y-4">
      <CommunityLeaderboard 
        communityId={primaryCommunity?.id || ''}
        userId={user?.id}
        key={`${primaryCommunity?.id}`} 
      />
    </div>
  );
}
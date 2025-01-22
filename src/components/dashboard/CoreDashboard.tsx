import { useState, useEffect } from 'react';
import { CompanyLogo } from './header/CompanyLogo';
import { DashboardHeader } from './header/DashboardHeader';
import { MyRocket } from './rocket/MyRocket';
import { RankStatus } from './rank/RankStatus';
import { QuestCard } from './quest/QuestCard';
import { ChallengeGrid } from './challenge/ChallengeGrid';
import { DailyBoosts } from './boosts/DailyBoosts';
import { useSupabase } from '../../contexts/SupabaseContext';
import { useDashboardData } from '../../hooks/useDashboardData';
import { usePlayerStats } from '../../hooks/usePlayerStats';
import { FPCongrats } from '../ui/fp-congrats';
import { useBoostState } from '../../hooks/useBoostState';

export function CoreDashboard() {
  const [fpEarned, setFpEarned] = useState<number | null>(null);
  const { user } = useSupabase();
  const { data, loading: dashboardLoading, refreshData } = useDashboardData(user);
  const { stats, loading: statsLoading, refreshStats } = usePlayerStats(user);
  const {
    selectedBoosts, 
    weeklyBoosts,
    daysUntilReset,
    completeBoost, 
    isLoading: boostLoading 
  } = useBoostState(user?.id);

  // Listen for dashboard update events
  useEffect(() => {
    const handleDashboardUpdate = async () => {
      try {
        await Promise.all([
          refreshData(),
          refreshStats()
        ]);
      } catch (err) {
        console.error('Error updating dashboard:', err);
      }
    };

    const handleUpdate = (event: Event) => {
      // Check if event has FP earned data
      if (event instanceof CustomEvent && event.detail?.fpEarned) {
        setFpEarned(event.detail.fpEarned);
      }

      if (event.type === 'dashboardUpdate') {
        handleDashboardUpdate();
      }
    };

    window.addEventListener('dashboardUpdate', handleUpdate);
    return () => window.removeEventListener('dashboardUpdate', handleUpdate);
  }, [refreshData, refreshStats]);

  // Handle closing the FP congrats modal
  const handleCloseModal = () => {
    setFpEarned(null);
  };

  // Show loading state while data is being fetched
  if ((dashboardLoading || statsLoading) && !data) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <div className="animate-spin rounded-full h-12 w-12 border-t-2 border-b-2 border-orange-500"></div>
      </div>
    );
  }

  // Ensure we have data before rendering
  if (!data) {
    return null;
  }

  return (
    <div className="relative">
      {fpEarned !== null && (
        <FPCongrats 
          fpEarned={fpEarned} 
          onClose={handleCloseModal}
        />
      )}
      <CompanyLogo />
      <DashboardHeader
        healthSpanYears={data.healthSpanYears}
        healthScore={data.healthScore}
        level={stats.level}
        nextLevelPoints={stats.nextLevelPoints}
      />
      <main className="max-w-6xl mx-auto px-4 py-6 space-y-6">
        <MyRocket
          level={stats.level}
          fuelPoints={stats.fuelPoints}
          nextLevelPoints={stats.nextLevelPoints}
          hasUpgrade={true}
        />
        <div id="leaderboard" className="space-y-4">
          <div className="flex items-center justify-between">
            <h2 className="text-xl font-bold text-white">Player Standings</h2>
          </div>
          <RankStatus />
        </div>
        <div id="quests">
          <QuestCard
            userId={user?.id}
            categoryScores={data.categoryScores}
          />
        </div>
        <div id="challenges">
          <ChallengeGrid 
            userId={user?.id}
            categoryScores={data.categoryScores}
            verificationRequirements={data.verificationRequirements}
          />
        </div>
        <div id="boosts">
          <DailyBoosts 
            burnStreak={stats.burnStreak}
            completedBoosts={data.completedBoosts}
            selectedBoosts={selectedBoosts}
            weeklyBoosts={weeklyBoosts}
            daysUntilReset={daysUntilReset}
            onCompleteBoost={completeBoost}
          />
        </div>
      </main>
    </div>
  );
}
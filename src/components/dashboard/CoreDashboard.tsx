import { useState, useEffect } from "react";
import { CompanyLogo } from "./header/CompanyLogo";
import { DashboardHeader } from "./header/DashboardHeader";
import { MyRocket } from "./rocket/MyRocket";
import { RankStatus } from "./rank/RankStatus";
import { QuestCard } from "./quest/QuestCard";
import { ChallengeGrid } from "./challenge/ChallengeGrid";
import { DailyBoosts } from "./boosts/DailyBoosts";
import { useSupabase } from "../../contexts/SupabaseContext";
import { useDashboardData } from "../../hooks/useDashboardData";
import { usePlayerStats } from "../../hooks/usePlayerStats";
import { FPCongrats } from "../ui/fp-congrats";
import { useBoostState } from "../../hooks/useBoostState";
import { supabase } from "../../lib/supabase";
import { formatInTimeZone } from 'date-fns-tz';

export function CoreDashboard() {
  const [fpEarned, setFpEarned] = useState<number | null>(null);
  const { user } = useSupabase();
  const {
    data,
    loading: dashboardLoading,
    refreshData,
  } = useDashboardData(user);
  const { stats, loading: statsLoading, refreshStats } = usePlayerStats(user);
  const {
    selectedBoosts,
    weeklyBoosts,
    daysUntilReset,
    completeBoost,
    isLoading: boostLoading,
  } = useBoostState(user?.id);

  // Listen for dashboard update events
  useEffect(() => {
    const handleDashboardUpdate = async () => {
      try {
        await Promise.all([refreshData(), refreshStats()]);
      } catch (err) {
        console.error("Error updating dashboard:", err);
      }
    };

    const handleUpdate = (event: Event) => {
      // Check if event has FP earned data
      if (event instanceof CustomEvent && event.detail?.fpEarned) {
        setFpEarned(event.detail.fpEarned);
      }

      if (event.type === "dashboardUpdate") {
        handleDashboardUpdate();
      }
    };

    window.addEventListener("dashboardUpdate", handleUpdate);
    return () => window.removeEventListener("dashboardUpdate", handleUpdate);
  }, [refreshData, refreshStats]);

  
  useEffect(() => {
    const NewYorkTimeZone = 'America/New_York';
    const resetBurnStreak = async () => {
      if (!user?.id) return;
      await supabase.rpc("check_and_reset_burn_streaks");
    };
  
    const scheduleReset = () => {
      const now = new Date();
      const newYorkTime = formatInTimeZone(now, NewYorkTimeZone, 'yyyy-MM-dd HH:mm:ssXXX');
      const midnight = new Date(newYorkTime);
      midnight.setHours(24, 0, 0, 0);
      const timeUntilMidnight = midnight.getTime() - now.getTime() + 60 * 1000; 
      const timeoutId = setTimeout(async () => {
        await resetBurnStreak();
        scheduleReset(); 
      }, timeUntilMidnight);
  
      return timeoutId;
    };
    const timeoutId = scheduleReset();
    return () => clearTimeout(timeoutId);
  }, [user?.id]); 
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
        <FPCongrats fpEarned={fpEarned} onClose={handleCloseModal} />
      )}
      <CompanyLogo />
      <DashboardHeader
        healthSpanYears={data.healthSpanYears}
        healthScore={data.healthScore}
        level={stats.level}
        nextLevelPoints={stats.nextLevelPoints}
      />
      <main className="max-w-6xl mx-auto px-4 py-6 flex flex-col h-screen gap-4">
        <MyRocket
          level={stats.level}
          fuelPoints={stats.fuelPoints}
          nextLevelPoints={stats.nextLevelPoints}
          hasUpgrade={true}
        />
        <RankStatus />
        <QuestCard userId={user?.id} categoryScores={data.categoryScores} />

        <ChallengeGrid
          userId={user?.id}
          categoryScores={data.categoryScores}
          verificationRequirements={data.verificationRequirements}
        />
        <DailyBoosts
          burnStreak={stats.burnStreak}
          completedBoosts={data.completedBoosts}
          selectedBoosts={selectedBoosts}
          weeklyBoosts={weeklyBoosts}
          daysUntilReset={daysUntilReset}
          onCompleteBoost={completeBoost}
        />
      </main>
    </div>
  );
}

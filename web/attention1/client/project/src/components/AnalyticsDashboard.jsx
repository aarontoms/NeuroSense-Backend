import { useState, useEffect } from 'react';
import { BarChart, Bar, PieChart, Pie, Cell, XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer, LineChart, Line, RadarChart, PolarGrid, PolarAngleAxis, PolarRadiusAxis, Radar } from 'recharts';
import { BarChart3, PieChartIcon, TrendingUp, RefreshCw, Activity, Eye, Users, Target } from 'lucide-react';
import API, { analyticsSummary, analyticsByStudent, analyticsStudentStimulus, analyticsStudentBest } from '../api';

const COLORS = {
  high: '#10B981',    // Green
  medium: '#F59E0B',  // Orange
  low: '#EF4444',     // Red
  primary: '#3B82F6', // Blue
  secondary: '#8B5CF6' // Purple
};

export default function AnalyticsDashboard({ studentId, refresh }) {
  const [summaryData, setSummaryData] = useState(null);
  const [studentData, setStudentData] = useState([]);
  const [stimulusData, setStimulusData] = useState([]);
  const [bestData, setBestData] = useState(null);
  const [attentionDistribution, setAttentionDistribution] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    loadAnalytics();
  }, [studentId, refresh]);

  const loadAnalytics = async () => {
    setLoading(true);
    try {
      const summary = await analyticsSummary();
      setSummaryData(summary);

      if (studentId) {
        const student = await analyticsByStudent(studentId);
        setStudentData(student);

        // Load stimulus-specific data
        try {
          const stimulusResponse = await analyticsStudentStimulus(studentId);
          setStimulusData(stimulusResponse);
        } catch (err) {
          console.error('Failed to load stimulus data:', err);
        }

        // Load best session/stimulus for conclusion
        try {
          const best = await analyticsStudentBest(studentId);
          setBestData(best);
        } catch (err) {
          console.error('Failed to load best analytics:', err);
        }

        // Calculate attention distribution from detailed analysis
        if (student.length > 0) {
          const totalHigh = student.reduce((sum, s) => sum + (s.high_attention_frames || 0), 0);
          const totalMedium = student.reduce((sum, s) => sum + (s.medium_attention_frames || 0), 0);
          const totalLow = student.reduce((sum, s) => sum + (s.low_attention_frames || 0), 0);

          setAttentionDistribution([
            { name: 'High (≥70%)', value: totalHigh, color: COLORS.high },
            { name: 'Medium (35-70%)', value: totalMedium, color: COLORS.medium },
            { name: 'Low (<35%)', value: totalLow, color: COLORS.low }
          ].filter(item => item.value > 0));
        }
      }
    } catch (err) {
      console.error('Failed to load analytics:', err);
    } finally {
      setLoading(false);
    }
  };

  const formatBarData = () => {
    if (!studentData || studentData.length === 0) return [];
    return studentData.map((item, idx) => ({
      name: item.stimulus_name || `Session ${idx + 1}`,
      attention: parseFloat((item.avg_attention * 100).toFixed(1)),
      blinks: item.blink_count || 0,
      frames: item.frames_collected || 0
    }));
  };

  const formatTimelineData = () => {
    if (!studentData || studentData.length === 0) return [];
    return studentData.map((record, idx) => ({
      session: idx + 1,
      avg: parseFloat((record.avg_attention * 100).toFixed(1)),
      max: parseFloat(((record.max_attention || record.avg_attention) * 100).toFixed(1)),
      min: parseFloat(((record.min_attention || record.avg_attention) * 100).toFixed(1)),
      stimulus: record.stimulus_name || 'Unknown'
    }));
  };

  const formatRadarData = () => {
    if (!studentData || studentData.length === 0) return [];
    
    const avgAttention = studentData.reduce((sum, s) => sum + s.avg_attention, 0) / studentData.length;
    const avgFaceDetection = studentData.reduce((sum, s) => sum + (s.frames_with_face || 0), 0) / 
                              studentData.reduce((sum, s) => sum + (s.frames_collected || 1), 0);
    const avgOnScreen = studentData.reduce((sum, s) => sum + (s.frames_on_screen || 0), 0) / 
                        studentData.reduce((sum, s) => sum + (s.frames_collected || 1), 0);
    
    return [
      { metric: 'Attention', value: avgAttention * 100 },
      { metric: 'Face Detection', value: avgFaceDetection * 100 },
      { metric: 'On Screen', value: avgOnScreen * 100 },
      { metric: 'Engagement', value: avgAttention * avgFaceDetection * 100 }
    ];
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center py-8 md:py-12">
        <div className="text-center">
          <RefreshCw className="animate-spin text-blue-600 mx-auto mb-4" size={40} />
          <p className="text-gray-600 text-sm md:text-base">Loading analytics...</p>
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-4 md:space-y-6">
      {/* Summary Cards */}
      {summaryData && (
        <div className="grid grid-cols-2 md:grid-cols-4 gap-2 md:gap-4">
          <div className="bg-gradient-to-br from-blue-500 to-blue-600 rounded-lg shadow-lg p-4 md:p-6 text-white">
            <div className="flex items-center justify-between mb-2">
              <Activity size={24} className="md:w-8 md:h-8 opacity-80" />
              <span className="text-2xl md:text-3xl font-bold text-right">{summaryData.total_sessions || 0}</span>
            </div>
            <p className="text-blue-100 text-xs md:text-sm font-medium">Total Sessions</p>
          </div>

          <div className="bg-gradient-to-br from-green-500 to-green-600 rounded-lg shadow-lg p-4 md:p-6 text-white">
            <div className="flex items-center justify-between mb-2">
              <TrendingUp size={24} className="md:w-8 md:h-8 opacity-80" />
              <span className="text-2xl md:text-3xl font-bold text-right">
                {summaryData.avg_attention ? (summaryData.avg_attention * 100).toFixed(1) : 0}%
              </span>
            </div>
            <p className="text-green-100 text-xs md:text-sm font-medium">Avg Attention</p>
          </div>

          <div className="bg-gradient-to-br from-purple-500 to-purple-600 rounded-lg shadow-lg p-4 md:p-6 text-white">
            <div className="flex items-center justify-between mb-2">
              <Users size={24} className="md:w-8 md:h-8 opacity-80" />
              <span className="text-2xl md:text-3xl font-bold text-right">{summaryData.total_students || 0}</span>
            </div>
            <p className="text-purple-100 text-xs md:text-sm font-medium">Total Students</p>
          </div>

          <div className="bg-gradient-to-br from-orange-500 to-orange-600 rounded-lg shadow-lg p-4 md:p-6 text-white">
            <div className="flex items-center justify-between mb-2">
              <Eye size={24} className="md:w-8 md:h-8 opacity-80" />
              <span className="text-2xl md:text-3xl font-bold text-right">{summaryData.total_frames || 0}</span>
            </div>
            <p className="text-orange-100 text-xs md:text-sm font-medium">Frames Analyzed</p>
          </div>
        </div>
      )}

      <div className="bg-white rounded-lg shadow-md p-4 md:p-6">
        <div className="flex items-center gap-2 mb-4 md:mb-6">
          <BarChart3 className="text-blue-600 flex-shrink-0" size={20} />
          <h2 className="text-lg md:text-2xl font-bold text-gray-800">Detailed Analytics</h2>
        </div>

        {/* Best Summary Cards */}
        {bestData && (bestData.best_session || bestData.best_stimulus) && (
          <div className="grid grid-cols-1 md:grid-cols-2 gap-3 md:gap-4 mb-6">
            {bestData.best_session && (
              <div className="bg-gradient-to-br from-indigo-500 to-indigo-600 rounded-lg shadow p-3 md:p-4 text-white">
                <h4 className="text-xs md:text-sm uppercase tracking-wide opacity-80">Best Session</h4>
                <div className="mt-2 flex items-center justify-between">
                  <div>
                    <div className="text-sm md:text-lg font-semibold truncate">{bestData.best_session.stimulus_name || 'Unknown'}</div>
                    <div className="text-indigo-100 text-xs md:text-sm">Frames: {bestData.best_session.frames_collected || 0}, Blinks: {bestData.best_session.blink_count || 0}</div>
                  </div>
                  <div className="text-2xl md:text-3xl font-bold whitespace-nowrap ml-2">{(bestData.best_session.avg_attention * 100).toFixed(1)}%</div>
                </div>
              </div>
            )}
            {bestData.best_stimulus && (
              <div className="bg-gradient-to-br from-green-500 to-green-600 rounded-lg shadow p-3 md:p-4 text-white">
                <h4 className="text-xs md:text-sm uppercase tracking-wide opacity-80">Best Stimulus</h4>
                <div className="mt-2 flex items-center justify-between">
                  <div>
                    <div className="text-sm md:text-lg font-semibold truncate">{bestData.best_stimulus.stimulus_name || 'Unknown'}</div>
                    <div className="text-green-100 text-xs md:text-sm">Sessions: {bestData.best_stimulus.sessions || 0}</div>
                  </div>
                  <div className="text-2xl md:text-3xl font-bold whitespace-nowrap ml-2">{(bestData.best_stimulus.avg_attention * 100).toFixed(1)}%</div>
                </div>
              </div>
            )}
          </div>
        )}

        {studentData.length === 0 ? (
          <div className="text-center py-8 md:py-12 text-gray-500">
            <Eye className="mx-auto mb-4 text-gray-400" size={48} />
            <p className="text-lg md:text-xl font-semibold mb-2">No Session Data Yet</p>
            <p className="text-sm md:text-base">Complete a monitoring session to see detailed analytics here.</p>
          </div>
        ) : (
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-4 md:gap-6">
            {/* Stimulus Focus Performance */}
            {stimulusData.length > 0 && (
              <div className="bg-gray-50 rounded-lg p-3 md:p-4 lg:col-span-2 overflow-x-auto">
                <div className="flex items-center gap-2 mb-4">
                  <Target className="text-indigo-600 flex-shrink-0" size={20} />
                  <h3 className="text-base md:text-lg font-semibold text-gray-700">
                    Focus by Stimulus
                  </h3>
                </div>
                <ResponsiveContainer width="100%" height={250} minWidth={280}>
                  <BarChart data={stimulusData}>
                    <CartesianGrid strokeDasharray="3 3" />
                    <XAxis dataKey="stimulus_name" angle={-20} textAnchor="end" height={60} tick={{ fontSize: 12 }} />
                    <YAxis yAxisId="left" label={{ value: 'Avg Attention %', angle: -90, position: 'insideLeft', offset: 10 }} tick={{ fontSize: 12 }} />
                    <YAxis yAxisId="right" orientation="right" label={{ value: 'Sessions', angle: 90, position: 'insideRight', offset: 10 }} tick={{ fontSize: 12 }} />
                    <Tooltip />
                    <Legend wrapperStyle={{ fontSize: 12 }} />
                    <Bar yAxisId="left" dataKey="avg_attention" fill={COLORS.primary} name="Avg Attention" />
                    <Bar yAxisId="right" dataKey="total_sessions" fill={COLORS.secondary} name="Sessions" />
                  </BarChart>
                </ResponsiveContainer>
              </div>
            )}

            {/* Attention Distribution Pie Chart */}
            {attentionDistribution.length > 0 && (
              <div className="bg-gray-50 rounded-lg p-3 md:p-4">
                <div className="flex items-center gap-2 mb-4">
                  <PieChartIcon className="text-green-600 flex-shrink-0" size={20} />
                  <h3 className="text-base md:text-lg font-semibold text-gray-700">
                    Attention Distribution
                  </h3>
                </div>
                <ResponsiveContainer width="100%" height={250} minWidth={250}>
                  <PieChart>
                    <Pie
                      data={attentionDistribution}
                      cx="50%"
                      cy="50%"
                      labelLine={false}
                      label={({ name, percent }) =>
                        `${name.split(' ')[0]}: ${(percent * 100).toFixed(0)}%`
                      }
                      outerRadius={70}
                      fill="#8884d8"
                      dataKey="value"
                    >
                      {attentionDistribution.map((entry, index) => (
                        <Cell key={`cell-${index}`} fill={entry.color} />
                      ))}
                    </Pie>
                    <Tooltip formatter={(value) => `${value} frames`} />
                    <Legend wrapperStyle={{ fontSize: 12 }} />
                  </PieChart>
                </ResponsiveContainer>
              </div>
            )}

            {/* Session Performance Bar Chart */}
            {formatBarData().length > 0 && (
              <div className="bg-gray-50 rounded-lg p-3 md:p-4">
                <div className="flex items-center gap-2 mb-4">
                  <BarChart3 className="text-blue-600 flex-shrink-0" size={20} />
                  <h3 className="text-base md:text-lg font-semibold text-gray-700">
                    Attention by Session
                  </h3>
                </div>
                <ResponsiveContainer width="100%" height={250} minWidth={250}>
                  <BarChart data={formatBarData()}>
                    <CartesianGrid strokeDasharray="3 3" />
                    <XAxis dataKey="name" angle={-20} textAnchor="end" height={60} tick={{ fontSize: 12 }} />
                    <YAxis 
                      label={{ value: 'Attention %', angle: -90, position: 'insideLeft', offset: 10 }}
                      domain={[0, 100]}
                      tick={{ fontSize: 12 }}
                    />
                    <Tooltip />
                    <Legend wrapperStyle={{ fontSize: 12 }} />
                    <Bar dataKey="attention" fill={COLORS.primary} name="Attention %" />
                  </BarChart>
                </ResponsiveContainer>
              </div>
            )}

            {/* Attention Timeline */}
            {formatTimelineData().length > 0 && (
              <div className="bg-gray-50 rounded-lg p-3 md:p-4 lg:col-span-2 overflow-x-auto">
                <div className="flex items-center gap-2 mb-4">
                  <TrendingUp className="text-purple-600 flex-shrink-0" size={20} />
                  <h3 className="text-base md:text-lg font-semibold text-gray-700">
                    Attention Trend
                  </h3>
                </div>
                <ResponsiveContainer width="100%" height={250} minWidth={280}>
                  <LineChart data={formatTimelineData()}>
                    <CartesianGrid strokeDasharray="3 3" />
                    <XAxis 
                      dataKey="session" 
                      label={{ value: 'Session', position: 'insideBottom', offset: -5 }}
                      tick={{ fontSize: 12 }}
                    />
                    <YAxis 
                      label={{ value: 'Attention %', angle: -90, position: 'insideLeft', offset: 10 }}
                      domain={[0, 100]}
                      tick={{ fontSize: 12 }}
                    />
                    <Tooltip />
                    <Legend wrapperStyle={{ fontSize: 12 }} />
                    <Line 
                      type="monotone" 
                      dataKey="avg" 
                      stroke={COLORS.secondary} 
                      strokeWidth={2} 
                      name="Average" 
                      dot={{ r: 3 }}
                    />
                    <Line 
                      type="monotone" 
                      dataKey="max" 
                      stroke={COLORS.high} 
                      strokeWidth={1} 
                      name="Maximum"
                      strokeDasharray="5 5"
                    />
                    <Line 
                      type="monotone" 
                      dataKey="min" 
                      stroke={COLORS.low} 
                      strokeWidth={1} 
                      name="Minimum"
                      strokeDasharray="5 5"
                    />
                  </LineChart>
                </ResponsiveContainer>
              </div>
            )}

            {/* Radar Chart for Overall Performance */}
            {formatRadarData().length > 0 && (
              <div className="bg-gray-50 rounded-lg p-3 md:p-4 lg:col-span-2">
                <div className="flex items-center gap-2 mb-4">
                  <Activity className="text-indigo-600 flex-shrink-0" size={20} />
                  <h3 className="text-base md:text-lg font-semibold text-gray-700">
                    Overall Performance
                  </h3>
                </div>
                <ResponsiveContainer width="100%" height={250} minWidth={280}>
                  <RadarChart data={formatRadarData()}>
                    <PolarGrid />
                    <PolarAngleAxis dataKey="metric" />
                    <PolarRadiusAxis angle={90} domain={[0, 100]} />
                    <Radar 
                      name="Performance" 
                      dataKey="value" 
                      stroke="#6366F1" 
                      fill="#6366F1" 
                      fillOpacity={0.6} 
                    />
                    <Tooltip formatter={(value) => `${value.toFixed(1)}%`} />
                  </RadarChart>
                </ResponsiveContainer>
              </div>
            )}
          </div>
        )}
      </div>

      {/* Detailed Session Table */}
      {studentData.length > 0 && (
        <div className="bg-white rounded-lg shadow-md p-6">
          <h3 className="text-xl font-bold mb-4 text-gray-800 flex items-center gap-2">
            <Activity size={24} className="text-blue-600" />
            Session History
          </h3>
          <div className="overflow-x-auto">
            <table className="min-w-full divide-y divide-gray-200">
              <thead className="bg-gray-50">
                <tr>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Session
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Stimulus
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Avg Attention
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Range
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    High/Med/Low
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Blinks
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Frames
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Date
                  </th>
                </tr>
              </thead>
              <tbody className="bg-white divide-y divide-gray-200">
                {studentData.map((record, idx) => (
                  <tr key={idx} className="hover:bg-gray-50">
                    <td className="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
                      #{idx + 1}
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                      {record.stimulus_name || 'Unknown'}
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm">
                      <div className="flex items-center gap-2">
                        <div className="w-16">
                          <span className={`font-bold ${
                            record.avg_attention >= 0.7 ? 'text-green-600' :
                            record.avg_attention >= 0.35 ? 'text-orange-600' :
                            'text-red-600'
                          }`}>
                            {(record.avg_attention * 100).toFixed(1)}%
                          </span>
                        </div>
                        <div className="flex-1 bg-gray-200 rounded-full h-2 w-24">
                          <div
                            className={`h-2 rounded-full ${
                              record.avg_attention >= 0.7 ? 'bg-green-500' :
                              record.avg_attention >= 0.35 ? 'bg-orange-500' :
                              'bg-red-500'
                            }`}
                            style={{ width: `${(record.avg_attention * 100)}%` }}
                          />
                        </div>
                      </div>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-600">
                      <span className="text-green-600 font-semibold">
                        {((record.max_attention || record.avg_attention) * 100).toFixed(0)}%
                      </span>
                      {' - '}
                      <span className="text-red-600 font-semibold">
                        {((record.min_attention || record.avg_attention) * 100).toFixed(0)}%
                      </span>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                      <div className="flex gap-1">
                        <span className="px-2 py-1 bg-green-100 text-green-800 rounded text-xs font-medium">
                          {record.high_attention_frames || 0}
                        </span>
                        <span className="px-2 py-1 bg-orange-100 text-orange-800 rounded text-xs font-medium">
                          {record.medium_attention_frames || 0}
                        </span>
                        <span className="px-2 py-1 bg-red-100 text-red-800 rounded text-xs font-medium">
                          {record.low_attention_frames || 0}
                        </span>
                      </div>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                      <span className="px-2 py-1 bg-blue-100 text-blue-800 rounded text-xs font-medium">
                        {record.blink_count || 0}
                      </span>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                      <div className="text-xs">
                        <div>{record.frames_collected || 0} total</div>
                        <div className="text-gray-500">
                          {record.frames_with_face || 0} w/ face
                        </div>
                      </div>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                      {record.timestamp ? new Date(record.timestamp * 1000).toLocaleString() : 'N/A'}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* Stimulus Focus Comparison Table */}
      {stimulusData.length > 0 && (
        <div className="bg-white rounded-lg shadow-md p-6">
          <h3 className="text-xl font-bold mb-4 text-gray-800 flex items-center gap-2">
            <Target size={24} className="text-indigo-600" />
            Focus by Stimulus
          </h3>
          <div className="overflow-x-auto">
            <table className="min-w-full divide-y divide-gray-200">
              <thead className="bg-gray-50">
                <tr>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Stimulus Name
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Sessions
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Avg Attention
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Focus Score
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Focus Distribution
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Total Blinks
                  </th>
                </tr>
              </thead>
              <tbody className="bg-white divide-y divide-gray-200">
                {stimulusData.map((stimulus, idx) => (
                  <tr key={idx} className="hover:bg-gray-50">
                    <td className="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
                      {stimulus.stimulus_name || 'Unknown'}
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                      <span className="px-3 py-1 bg-blue-100 text-blue-800 rounded-full text-xs font-bold">
                        {stimulus.total_sessions}
                      </span>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm">
                      <div className="flex items-center gap-2">
                        <span className={`font-bold ${
                          stimulus.avg_attention >= 0.7 ? 'text-green-600' :
                          stimulus.avg_attention >= 0.35 ? 'text-orange-600' :
                          'text-red-600'
                        }`}>
                          {(stimulus.avg_attention * 100).toFixed(1)}%
                        </span>
                        <div className="w-16 bg-gray-200 rounded-full h-2">
                          <div
                            className={`h-2 rounded-full ${
                              stimulus.avg_attention >= 0.7 ? 'bg-green-500' :
                              stimulus.avg_attention >= 0.35 ? 'bg-orange-500' :
                              'bg-red-500'
                            }`}
                            style={{ width: `${stimulus.avg_attention * 100}%` }}
                          />
                        </div>
                      </div>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm">
                      <span className={`px-3 py-1 rounded-full font-bold text-white text-xs ${
                        stimulus.focus_score >= 70 ? 'bg-green-600' :
                        stimulus.focus_score >= 40 ? 'bg-orange-600' :
                        'bg-red-600'
                      }`}>
                        {stimulus.focus_score}%
                      </span>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                      <div className="flex gap-1">
                        <div className="flex flex-col items-center">
                          <span className="text-xs font-semibold text-green-700">H</span>
                          <span className="px-2 py-1 bg-green-100 text-green-800 rounded text-xs font-medium">
                            {stimulus.focus_distribution.high}
                          </span>
                        </div>
                        <div className="flex flex-col items-center">
                          <span className="text-xs font-semibold text-orange-700">M</span>
                          <span className="px-2 py-1 bg-orange-100 text-orange-800 rounded text-xs font-medium">
                            {stimulus.focus_distribution.medium}
                          </span>
                        </div>
                        <div className="flex flex-col items-center">
                          <span className="text-xs font-semibold text-red-700">L</span>
                          <span className="px-2 py-1 bg-red-100 text-red-800 rounded text-xs font-medium">
                            {stimulus.focus_distribution.low}
                          </span>
                        </div>
                      </div>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                      <span className="px-3 py-1 bg-purple-100 text-purple-800 rounded-full text-xs font-semibold">
                        {stimulus.total_blinks}
                      </span>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}
    </div>
  );
}

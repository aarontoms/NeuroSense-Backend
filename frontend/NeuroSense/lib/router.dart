import 'package:go_router/go_router.dart';
import 'package:autism/screens/login_screen.dart';
import 'package:autism/screens/signup_screen.dart';
import 'package:autism/screens/splash_screen.dart';
import 'package:autism/screens/student/student_scaffold.dart';
import 'package:autism/screens/student/home_screen.dart';
import 'package:autism/screens/student/explore_screen.dart';
import 'package:autism/screens/student/profile_screen.dart';
import 'package:autism/screens/student/sensory_slime_activity.dart';
import 'package:autism/screens/student/content_list_screen.dart';
import 'package:autism/screens/student/connect_dots_screen.dart';
import 'package:autism/screens/teacher/upload_content_screen.dart';
import 'package:autism/screens/student/autism_detection_screen.dart';
import 'package:autism/screens/teacher/students_list_screen.dart';
import 'package:autism/screens/parent/students_list_screen.dart';
import 'package:autism/screens/shared/student_detail_screen.dart';
import 'package:autism/screens/student/iframe_content_screen.dart';
import 'package:autism/screens/student/attention_monitor_screen.dart';
import 'package:autism/screens/student/attention_analytics_screen.dart';

final GoRouter router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    GoRoute(path: '/signup', builder: (context, state) => const SignupScreen()),

    // Profile page - standalone, NO navbar or FAB button
    GoRoute(
      path: '/profile',
      builder: (context, state) => const ProfileScreen(),
    ),

    // Sensory Slime Activity - standalone, with back button
    GoRoute(
      path: '/sensory-slime',
      builder: (context, state) => const SensorySlimeActivity(),
    ),

    // Teacher Upload Screen
    GoRoute(
      path: '/teacher/upload',
      builder: (context, state) => const UploadContentScreen(),
    ),

    // Content List Screen - shows teacher-uploaded content
    GoRoute(
      path: '/content-list',
      builder: (context, state) => const ContentListScreen(),
    ),

    // Connect Dots Game - standalone
    GoRoute(
      path: '/connect-dots',
      builder: (context, state) => const ConnectDotsScreen(),
    ),

    // Iframe Template - standalone
    GoRoute(
      path: '/iframe-activity',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        return IframeContentScreen(
          url: extra?['url'] ?? 'https://mv1z79jg-5173.inc1.devtunnels.ms/',
          title: extra?['title'] ?? 'Activity',
        );
      },
    ),

    // All student pages share the same navbar + profile FAB
    ShellRoute(
      builder: (context, router, child) => StudentScaffold(child: child),
      routes: [
        GoRoute(
          path: '/home',
          builder: (context, state) => const StudentHomeScreen(),
        ),
        GoRoute(
          path: '/explore',
          builder: (context, state) => const ExploreScreen(),
        ),
        // GoRoute(
        //   path: '/activities',
        //   builder: (context, state) => const ActivitiesScreen(),
        // ),
        // GoRoute(
        //  path: '/courses',
        //  builder: (context, state) => const CoursesScreen(),
        //),
        GoRoute(
          path: '/parent/students',
          builder: (context, state) => const ParentStudentsListScreen(),
        ),
        GoRoute(
          path: '/teacher/students',
          builder: (context, state) => const TeacherStudentsListScreen(),
        ),
        // Student Detail Screens - inside ShellRoute to maintain navigation
        GoRoute(
          path: '/parent/student-detail',
          builder: (context, state) {
            final student = state.extra as Map<String, dynamic>;
            return StudentDetailScreen(student: student);
          },
        ),
        GoRoute(
          path: '/teacher/student-detail',
          builder: (context, state) {
            final student = state.extra as Map<String, dynamic>;
            return StudentDetailScreen(student: student);
          },
        ),
      ],
    ),
    GoRoute(
      path: '/autism-detection',
      builder: (context, state) => const AutismDetectionScreen(),
    ),
    GoRoute(
      path: '/attention-monitor',
      builder: (context, state) => const AttentionMonitorScreen(),
    ),
    GoRoute(
      path: '/attention-analytics',
      builder: (context, state) => const AttentionAnalyticsScreen(),
    ),
  ],
);

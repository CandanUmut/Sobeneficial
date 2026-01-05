import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/auth/sign_in_screen.dart';
import 'screens/home/home_shell.dart';
import 'screens/rfh/rfh_create_screen.dart';
import 'screens/rfh/rfh_detail_screen.dart';
import 'screens/qa/qa_create_question_screen.dart';
import 'screens/content/content_create_screen.dart';
import 'screens/projects/projects_create_screen.dart';
import 'screens/events/events_create_screen.dart';

// PSM (Professional Support Module)
import 'screens/psm/offers_list_screen.dart';
import 'screens/psm/offer_detail_screen.dart';
import 'screens/psm/my_requests_screen.dart';
import 'screens/psm/engagement_detail_screen.dart';
import 'screens/psm/offer_create_screen.dart';
// OPTIONAL: uncomment if you added the manager screen
import 'screens/psm/offer_slots_screen.dart';
import 'screens/psm/practitioner_profile_screen.dart';
import 'screens/psm/profile_edit_screen.dart';


class AuthNotifier extends ChangeNotifier {
  AuthNotifier() {
    Supabase.instance.client.auth.onAuthStateChange.listen((_) => notifyListeners());
  }
  bool get isSignedIn => Supabase.instance.client.auth.currentSession != null;
}

final _auth = AuthNotifier();

final appRouter = GoRouter(
  initialLocation: '/',
  refreshListenable: _auth,
  routes: [
    // Auth
    GoRoute(
      path: '/signin',
      name: 'signin',
      builder: (ctx, st) => const SignInScreen(),
    ),

    // Home shell
    GoRoute(
      path: '/',
      name: 'home',
      builder: (ctx, st) => const HomeShell(child: SizedBox()),
    ),

    // RFH
    GoRoute(path: '/rfh/new', name: 'rfh_new', builder: (c, s) => const RFHCreateScreen()),
    GoRoute(path: '/rfh/:id', name: 'rfh_detail', builder: (c, s) => RFHDetailScreen(id: s.pathParameters['id']!)),

    // QA / Content / Projects / Events
    GoRoute(path: '/qa/new',      name: 'qa_new',      builder: (c, s) => const QACreateQuestionScreen()),
    GoRoute(path: '/content/new', name: 'content_new', builder: (c, s) => const ContentCreateScreen()),
    GoRoute(path: '/projects/new',name: 'project_new', builder: (c, s) => const ProjectsCreateScreen()),
    GoRoute(path: '/events/new',  name: 'event_new',   builder: (c, s) => const EventsCreateScreen()),

    // -------- PSM --------
    // convenience redirect: /psm -> /psm/offers
    GoRoute(
      path: '/psm',
      name: 'psm_root',
      redirect: (_, __) => '/psm/offers',
    ),

    // lists & detail
    GoRoute(path: '/psm/offers',        name: 'psm_offers',       builder: (_, __) => const OffersListScreen()),
    GoRoute(path: '/psm/offers/new',    name: 'psm_offer_new',    builder: (_, __) => const OfferCreateScreen()),
    GoRoute(path: '/psm/offers/:id',    name: 'psm_offer_detail', builder: (_, st) => OfferDetailScreen(id: st.pathParameters['id']!)),

    // requests & engagements
    GoRoute(path: '/psm/requests',       name: 'psm_requests',    builder: (_, __) => const MyRequestsScreen()),
    GoRoute(path: '/psm/engagements/:id',name: 'psm_eng',         builder: (_, st) => EngagementDetailScreen(id: st.pathParameters['id']!)),
    // Public practitioner profile (id OR username in :id)
    GoRoute(
      path: '/profiles/:id',
      name: 'profile', // <-- must be exactly "profile"
      builder: (_, st) => PractitionerProfileScreen(profileId: st.pathParameters['id']!),
    ),
    GoRoute(
      path: '/events/:id',
      name: 'event_detail',
      builder: (c, s) => EventDetailScreen(eventId: s.pathParameters['id']!),
    ),


// Edit my profile
    GoRoute(
      path: '/profiles/me/edit',
      name: 'profile_edit',
      builder: (_, __) => const ProfileEditScreen(),
    ),


    // OPTIONAL: only if you added OfferSlotsScreen
    // GoRoute(
    //   path: '/psm/offers/:id/slots',
    //   name: 'psm_offer_slots',
    //   builder: (_, st) => OfferSlotsScreen(offerId: st.pathParameters['id']!),
    // ),
  ],
  redirect: (ctx, state) {
    final signedIn = _auth.isSignedIn;
    final path = state.uri.path;

    if (!signedIn && path != '/signin') return '/signin';
    if (signedIn && path == '/signin') return '/';
    return null;
  },
  // fallback (keeps assertions from exploding in dev)
  errorBuilder: (ctx, st) => const SignInScreen(),
);

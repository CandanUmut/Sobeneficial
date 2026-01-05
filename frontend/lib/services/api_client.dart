import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config.dart';

class ApiClient {
  final _client = http.Client();

  Uri _u(String path, [Map<String, dynamic>? q]) =>
      Uri.parse(BACKEND_BASE_URL + API_PREFIX + path).replace(queryParameters: q);

  Map<String, String> _headers({bool jsonBody = false}) {
    final token = Supabase.instance.client.auth.currentSession?.accessToken;
    final h = <String, String>{
      'Accept': 'application/json',
      if (jsonBody) 'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
    return h;
  }

  // --------- Health/Auth/Profile ----------
  Future<bool> health() async {
    final r = await _client.get(_u("/healthz"), headers: _headers());
    return r.statusCode == 200 && jsonDecode(r.body)['status'] == 'ok';
  }

  Future<Map<String, dynamic>?> me() async {
    final r = await _client.get(_u("/profiles/me"), headers: _headers());
    if (r.statusCode == 200) return jsonDecode(r.body);
    return null;
  }

  Future<bool> updateProfile(Map body) async {
    final r = await _client.put(_u("/profiles/me"),
        headers: _headers(jsonBody: true), body: jsonEncode(body));
    return r.statusCode == 200;
  }

  // --------- RFH ----------
  Future<List<dynamic>> listRFH({String? q, String? tag}) async {
    final r = await _client.get(_u("/rfh", {
      if (q != null) "q": q,
      if (tag != null) "tag": tag,
    }), headers: _headers());
    return r.statusCode == 200 ? (jsonDecode(r.body) as List) : [];
  }

  Future<Map<String, dynamic>?> getRFH(String id) async {
    final r = await _client.get(_u("/rfh/$id"), headers: _headers());
    return r.statusCode == 200 ? jsonDecode(r.body) : null;
  }

  Future<String?> createRFH(Map body) async {
    final r = await _client.post(_u("/rfh"),
        headers: _headers(jsonBody: true), body: jsonEncode(body));
    if (r.statusCode == 200) return jsonDecode(r.body)['id'];
    return null;
  }

  Future<List<dynamic>> matchRFH(String id) async {
    final r = await _client.get(_u("/match/$id"), headers: _headers());
    return r.statusCode == 200 ? (jsonDecode(r.body) as List) : [];
  }

  // --------- Content ----------
  Future<List<dynamic>> listContent({String? q, String? tag}) async {
    final r = await _client.get(_u("/content", {
      if (q != null) "q": q,
      if (tag != null) "tag": tag,
    }), headers: _headers());
    return r.statusCode == 200 ? (jsonDecode(r.body) as List) : [];
  }

  Future<String?> createContent(Map body) async {
    final r = await _client.post(_u("/content"),
        headers: _headers(jsonBody: true), body: jsonEncode(body));
    if (r.statusCode == 200) return jsonDecode(r.body)['id'];
    return null;
  }

  // --------- Q&A ----------
  Future<List<dynamic>> listQuestions({String? q, String? tag}) async {
    final r = await _client.get(_u("/qa/questions", {
      if (q != null) "q": q,
      if (tag != null) "tag": tag,
    }), headers: _headers());
    return r.statusCode == 200 ? (jsonDecode(r.body) as List) : [];
  }

  Future<String?> createQuestion(Map body) async {
    final r = await _client.post(_u("/qa/questions"),
        headers: _headers(jsonBody: true), body: jsonEncode(body));
    if (r.statusCode == 200) return jsonDecode(r.body)['id'];
    return null;
  }

  Future<List<dynamic>> listAnswers(String qid) async {
    final r = await _client.get(_u("/qa/questions/$qid/answers"), headers: _headers());
    return r.statusCode == 200 ? (jsonDecode(r.body) as List) : [];
  }

  Future<String?> createAnswer(Map body) async {
    final r = await _client.post(_u("/qa/answers"),
        headers: _headers(jsonBody: true), body: jsonEncode(body));
    if (r.statusCode == 200) return jsonDecode(r.body)['id'];
    return null;
  }

  // --------- Projects ----------
  Future<List<dynamic>> listProjects() async {
    final r = await _client.get(_u("/projects"), headers: _headers());
    return r.statusCode == 200 ? (jsonDecode(r.body) as List) : [];
  }

  Future<String?> createProject(Map body) async {
    final r = await _client.post(_u("/projects"),
        headers: _headers(jsonBody: true), body: jsonEncode(body));
    if (r.statusCode == 200) return jsonDecode(r.body)['id'];
    return null;
  }

  Future<bool> applyProject(String id, String? message) async {
    final r = await _client.post(_u("/projects/$id/apply"),
        headers: _headers(jsonBody: true), body: jsonEncode({"message": message}));
    return r.statusCode == 200;
  }

  // --------- Events ----------
  Future<List<dynamic>> listEvents() async {
    final r = await _client.get(_u("/events"), headers: _headers());
    return r.statusCode == 200 ? (jsonDecode(r.body) as List) : [];
  }

  Future<String?> createEvent(Map body) async {
    final r = await _client.post(_u("/events"),
        headers: _headers(jsonBody: true), body: jsonEncode(body));
    if (r.statusCode == 200) return jsonDecode(r.body)['id'];
    return null;
  }

  Future<bool> enrollEvent(String id) async {
    final r = await _client.post(_u("/events/$id/enroll"),
        headers: _headers(jsonBody: true), body: jsonEncode({}));
    return r.statusCode == 200;
  }

  // --------- Notifications ----------
  Future<List<dynamic>> myNotifications() async {
    final r = await _client.get(_u("/notifications"), headers: _headers());
    return r.statusCode == 200 ? (jsonDecode(r.body) as List) : [];
  }

  // --------- Q&A ----------
  Future<Map<String, dynamic>?> getQuestion(String id) async {
    final r = await _client.get(_u("/qa/questions/$id"), headers: _headers());
    return r.statusCode == 200 ? jsonDecode(r.body) : null;
  }

  Future<bool> deleteQuestion(String id) async {
    final r = await _client.delete(_u("/qa/questions/$id"), headers: _headers());
    return r.statusCode == 204;
  }

  // --------- Metrics helpers (varsa backend’de) ----------
  Future<void> addView(String entity, String id) async {
    // backend’inde /api/views gibi bir endpoint varsa; yoksa kaldır.
    try {
      await _client.post(_u("/views"),
          headers: _headers(jsonBody: true),
          body: jsonEncode({"entity": entity, "entity_id": id}));
    } catch (_) {}
  }

  Future<bool> rate(String entity, String id, int stars) async {
    try {
      final r = await _client.post(_u("/ratings"),
          headers: _headers(jsonBody: true),
          body: jsonEncode({"entity": entity, "entity_id": id, "stars": stars}));
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // services/api_client.dart (ek)
  Future<bool> deleteRFH(String id) async {
    final r = await _client.delete(_u("/rfh/$id"), headers: _headers());
    return r.statusCode == 204;
  }

  // WALLET
  Future<Map<String, dynamic>?> walletMe() async {
    final r = await _client.get(_u("/wallet/me"), headers: _headers());
    if (r.statusCode == 200) return jsonDecode(r.body);
    return null;
  }

  Future<bool> tipUser(String toUserId, int amount, {String reason = "tip"}) async {
    final uri = _u("/wallet/tip", {"to_user": toUserId, "amount": "$amount", "reason": reason});
    final r = await _client.post(uri, headers: _headers());
    return r.statusCode == 200;
  }

  // --------- Comments ----------
  Future<List<dynamic>> listComments(String entity, String id) async {
    final r = await _client.get(_u("/comments", {"entity": entity, "id": id}), headers: _headers());
    return r.statusCode == 200 ? (jsonDecode(r.body) as List) : [];
  }

  Future<bool> createComment(String entity, String id, String body) async {
    final r = await _client.post(
      _u("/comments"),
      headers: _headers(jsonBody: true),
      body: jsonEncode({"entity": entity, "entity_id": id, "body": body}),
    );
    return r.statusCode == 200;
  }
//   PSM ROUTES
// ----------------- PSM: Offers -----------------
  Future<Map<String, dynamic>> listOffers({
    String? q, String? type, String? tag, String? fee, String? region, String? lang,
    int page = 1, int pageSize = 20, String sort = 'new',
  }) async {
    final r = await _client.get(_u("/psm/offers", {
      if (q != null && q.isNotEmpty) "q": q,
      if (type != null) "type": type,
      if (tag != null) "tag": tag,
      if (fee != null) "fee": fee,
      if (region != null) "region": region,
      if (lang != null) "lang": lang,
      "page": "$page",
      "page_size": "$pageSize",
      "sort": sort,
    }), headers: _headers());
    if (r.statusCode == 200) return jsonDecode(r.body) as Map<String, dynamic>;
    return {"items": [], "page": 1, "page_size": pageSize, "total": 0};
  }

  Future<Map<String, dynamic>?> getOffer(String id) async {
    final r = await _client.get(_u("/psm/offers/$id"), headers: _headers());
    if (r.statusCode == 200) return jsonDecode(r.body);
    return null;
  }

// ----------------- PSM: Requests -----------------
  // ----------------- PSM: Requests -----------------
  Future<String?> createOfferRequest({
    required String offerId,
    required String message,
    List<Map<String, dynamic>> preferredTimes = const [],
    bool useGift = false, // NEW
  }) async {
    final body = <String, dynamic>{
      "offer_id": offerId,
      "message": message,
      if (preferredTimes.isNotEmpty) "preferred_times": preferredTimes,
      if (useGift) "use_gift": true, // NEW
    };
    final r = await _client.post(
      _u("/psm/requests"),
      headers: _headers(jsonBody: true),
      body: jsonEncode(body),
    );
    if (r.statusCode == 200) return (jsonDecode(r.body) as Map)["id"] as String?;
    return null;
  }


  Future<List<dynamic>> myRequests({String box = "sent"}) async {
    final r = await _client.get(_u("/psm/requests/mine", {"box": box}), headers: _headers());
    return r.statusCode == 200 ? (jsonDecode(r.body) as List) : [];
  }

  Future<bool> updateRequest(String id, Map body) async {
    final r = await _client.patch(_u("/psm/requests/$id"),
        headers: _headers(jsonBody: true), body: jsonEncode(body));
    return r.statusCode == 200;
  }

// ----------------- PSM: Engagements -----------------
  Future<Map<String, dynamic>?> getEngagement(String id) async {
    final r = await _client.get(_u("/psm/engagements/$id"), headers: _headers());
    if (r.statusCode == 200) return jsonDecode(r.body);
    return null;
  }

  Future<bool> updateEngagement(String id, Map body) async {
    final r = await _client.patch(_u("/psm/engagements/$id"),
        headers: _headers(jsonBody: true), body: jsonEncode(body));
    return r.statusCode == 200;
  }

// ----------------- PSM: AI helper -----------------
  Future<Map<String, dynamic>?> aiAnswer({required String question, required String topicTag}) async {
    final r = await _client.post(_u("/psm/ai/answer"),
        headers: _headers(jsonBody: true),
        body: jsonEncode({"question": question, "topic_tag": topicTag}));
    if (r.statusCode == 200) return jsonDecode(r.body);
    return null;
  }

  // --------- Profile (for capability check) ------------
  Future<Map<String, dynamic>?> getMyProfile() async {
    final r = await _client.get(_u("/profiles/me"), headers: _headers());
    if (r.statusCode == 200) return jsonDecode(r.body);
    return null;
  }

  Future<bool> canCreateOffer() async {
    final me = await getMyProfile();
    if (me == null) return false;
    final roles = (me["roles"] as List?)?.map((e) => e.toString()).toList() ?? const [];
    // allow anyone you consider “professional”: org / practitioner
    return roles.contains("org") || roles.contains("practitioner");
  }

// ----------------- PSM: Offers (create) -----------------
  Future<String?> createOffer({
    required String type, // legal|psychological|career|other
    required String title,
    String? description,
    List<String>? tags,
    required String feeType, // free|paid|sliding
    List<String>? languages,
    String? region,
    Map<String, dynamic>? availability,
  }) async {
    final r = await _client.post(_u("/psm/offers"),
        headers: _headers(jsonBody: true),
        body: jsonEncode({
          "type": type,
          "title": title,
          "description": description,
          "tags": tags ?? [],
          "fee_type": feeType,
          "languages": languages ?? [],
          "region": region,
          "availability": availability ?? {},
        }));
    if (r.statusCode == 200) return (jsonDecode(r.body) as Map)["id"]?.toString();
    return null;
  }

// ----------------- PSM: Requests (return response) -------------
  Future<Map<String, dynamic>?> updateRequestWithResponse(String id, Map body) async {
    final r = await _client.patch(_u("/psm/requests/$id"),
        headers: _headers(jsonBody: true), body: jsonEncode(body));
    if (r.statusCode == 200) return jsonDecode(r.body) as Map<String, dynamic>;
    return null;
  }
  // --------- PSM Slots ----------
  Future<List<Map<String, dynamic>>> listOfferSlots(
      String offerId, {
        String? fromIso,
        String? toIso,
      }) async {
    // Build base URI
    Uri uri = _u("/psm/offers/$offerId/slots");

    // Add optional query params if provided
    if (fromIso != null || toIso != null) {
      final qp = Map<String, String>.from(uri.queryParameters);
      if (fromIso != null) qp['from'] = fromIso; // <-- change keys if your backend expects different names
      if (toIso != null) qp['to'] = toIso;
      uri = uri.replace(queryParameters: qp);
    }

    final r = await _client.get(uri, headers: _headers());
    if (r.statusCode == 200) {
      final l = (jsonDecode(r.body) as List).cast<Map<String, dynamic>>();
      return l;
    }
    return [];
  }

  // Create request with a specific slot (sends {offer_id, message, slot_id})
  Future<String?> createOfferRequestWithSlot({
    required String offerId,
    required String message,
    required String slotId,
  }) async {
    final r = await _client.post(_u("/psm/requests"),
        headers: _headers(jsonBody: true),
        body: jsonEncode({
          "offer_id": offerId,
          "message": message,
          "slot_id": slotId, // backend will ignore if not used, but we use it for UX + later accept
        }));
    if (r.statusCode == 200) return (jsonDecode(r.body) as Map)["id"]?.toString();
    return null;
  }


  Future<String?> createOfferSlot({
    required String offerId,
    required String startAtIso,
    required String endAtIso,
    int capacity = 1,
    String? note,
  }) async {
    final r = await _client.post(_u("/psm/offers/$offerId/slots"),
        headers: _headers(jsonBody: true),
        body: jsonEncode({
          "start_at": startAtIso,
          "end_at": endAtIso,
          "capacity": capacity,
          "note": note,
        }));
    if (r.statusCode == 200) return (jsonDecode(r.body) as Map)["id"]?.toString();
    return null;
  }

  Future<bool> updateOfferSlot({
    required String offerId,
    required String slotId,
    String? status, // open|full|cancelled
    int? capacity,
    String? note,
  }) async {
    final r = await _client.patch(_u("/psm/offers/$offerId/slots/$slotId"),
        headers: _headers(jsonBody: true),
        body: jsonEncode({"status": status, "capacity": capacity, "note": note}));
    return r.statusCode == 200;
  }

  Future<bool> cancelOfferSlot({required String offerId, required String slotId}) async {
    final r = await _client.delete(_u("/psm/offers/$offerId/slots/$slotId"), headers: _headers());
    return r.statusCode == 200;
  }

  // lib/services/api_client.dart

// Gifts
  Future<Map<String, dynamic>> giftStats(String offerId) async {
    final r = await _client.get(_u("/psm/offers/$offerId/gifts/available"), headers: _headers());
    return r.statusCode == 200 ? (jsonDecode(r.body) as Map<String, dynamic>) : {"available": 0};
  }

  Future<bool> createGift({required String offerId, int units = 1, String? note}) async {
    final r = await _client.post(
      _u("/psm/offers/$offerId/gifts"),
      headers: _headers(jsonBody: true),
      body: jsonEncode({"units": units, if (note != null) "note": note}),
    );
    return r.statusCode == 200;
  }


  // ---- SLOTS ----
  Future<List<Map<String, dynamic>>> listOfferSlotsRange(
      String offerId, {
        DateTime? from,
        DateTime? to,
        bool onlyOpen = true,
      }) async {
    final q = <String, String>{
      if (from != null) "from": from.toUtc().toIso8601String().substring(0, 10),
      if (to != null) "to": to.toUtc().toIso8601String().substring(0, 10),
      if (onlyOpen) "only_open": "true",
    };
    final r = await _client.get(_u("/psm/offers/$offerId/slots", q), headers: _headers());
    if (r.statusCode != 200) return [];
    return (jsonDecode(r.body) as List).cast<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<List<Map<String, dynamic>>> nextSlots(String offerId, {int limit = 6}) async {
    final r = await _client.get(_u("/psm/offers/$offerId/next_slots", {"limit": "$limit"}),
        headers: _headers());
    if (r.statusCode != 200) return [];
    return (jsonDecode(r.body) as List).cast<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

// ---- OFFERS with inline next_slots ----
  Future<Map<String, dynamic>> listOffersWithNextSlots({
    String? q,
    String? type,
    String? tag,
    String? fee,
    String? region,
    String? lang,
    int page = 1,
    int pageSize = 20,
    String sort = "new",
    int limitSlots = 3,
  }) async {
    // AFTER:
    final r = await _client.get(_u("/psm/offers.with_next_slots", {
      "page": "$page",
      "page_size": "$pageSize",
      "sort": sort,
      "limit_slots": "$limitSlots",
      if (q != null && q.isNotEmpty) "q": q,
      if (type != null) "type": type,
      if (tag != null) "tag": tag,
      if (fee != null) "fee_type": fee,  // backend expects fee_type
      if (region != null) "region": region,
      if (lang != null) "lang": lang,
    }), headers: _headers());
    if (r.statusCode != 200) return {"items": <Map<String, dynamic>>[], "total": 0, "page": page};
    return Map<String, dynamic>.from(jsonDecode(r.body));
  }

// ---- PUBLIC PROFILE ----
  Future<Map<String, dynamic>?> getPublicProfile(String idOrUsername) async {
    final r = await _client.get(_u("/profiles/$idOrUsername"), headers: _headers());
    if (r.statusCode != 200) return null;
    return Map<String, dynamic>.from(jsonDecode(r.body));
  }

// ---- REVIEWS ----
  Future<List<Map<String, dynamic>>> getOfferReviews(String offerId,
      {int limit = 20, int offset = 0}) async {
    final r = await _client.get(
        _u("/psm/offers/$offerId/reviews", {"limit": "$limit", "offset": "$offset"}),
        headers: _headers());
    if (r.statusCode != 200) return [];
    return (jsonDecode(r.body) as List).cast<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<Map<String, dynamic>?> createReview(
      {required String engagementId, required int stars, required String comment}) async {
    final r = await _client.post(
      _u("/psm/engagements/$engagementId/reviews"),
      headers: _headers(jsonBody: true),
      body: jsonEncode({"stars": stars, "comment": comment}),
    );
    if (r.statusCode != 200) return null; // 403/409/400 gibi durumlar için null döndürüyoruz
    return Map<String, dynamic>.from(jsonDecode(r.body));
  }



  Future<Map<String, dynamic>?> updateMyProfile(Map<String, dynamic> patch) async {
    final r = await _client.patch(_u("/profiles/me"),
        headers: _headers(jsonBody: true), body: jsonEncode(patch));
    if (r.statusCode != 200) return null;
    return Map<String, dynamic>.from(jsonDecode(r.body));
  }
  // Search calendar (day buckets across offers)
  Future<List<Map<String, dynamic>>> availabilityByDay({
    required DateTime from,
    required DateTime to,
    String? q, String? type, String? tag, String? fee, String? region, String? lang,
  }) async {
    final r = await _client.get(_u("/psm/offers/availability.by_day", {
      "from": from.toUtc().toIso8601String().substring(0,10),
      "to":   to.toUtc().toIso8601String().substring(0,10),
      if (q != null && q.isNotEmpty) "q": q,
      if (type != null) "type": type,
      if (tag != null) "tag": tag,
      if (fee != null) "fee_type": fee,
      if (region != null) "region": region,
      if (lang != null) "lang": lang,
    }), headers: _headers());
    if (r.statusCode != 200) return [];
    return (jsonDecode(r.body) as List).cast<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

// Practitioner calendar
  Future<List<Map<String, dynamic>>> profileAvailabilityByDay(
      String idOrUsername, {
        required DateTime from,
        required DateTime to,
      }) async {
    final r = await _client.get(_u("/profiles/$idOrUsername/availability.by_day", {
      "from": from.toUtc().toIso8601String().substring(0,10),
      "to":   to.toUtc().toIso8601String().substring(0,10),
    }), headers: _headers());
    if (r.statusCode != 200) return [];
    return (jsonDecode(r.body) as List).cast<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<Map<String, dynamic>?> getEvent(String id) async {
    final r = await _client.get(_u("/events/$id"), headers: _headers());
    if (r.statusCode == 200) {
      return jsonDecode(r.body) as Map<String, dynamic>;
    }
    return null;
  }

  Future<bool> rsvpEvent(String id) async {
    final r = await _client.post(
      _u("/events/$id/rsvp"),
      headers: _headers(jsonBody: true),
      body: jsonEncode({}),
    );
    return r.statusCode == 200;
  }













}

final api = ApiClient();

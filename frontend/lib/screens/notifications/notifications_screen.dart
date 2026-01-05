import 'package:flutter/material.dart';
import '../../services/api_client.dart';
import '../../widgets/common.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late Future<List<dynamic>> _f;
  @override
  void initState(){ super.initState(); _f = api.myNotifications(); }
  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: "Alerts",
      body: FutureBuilder(
        future: _f,
        builder: (c, s){
          if (!s.hasData) return const Loading();
          final items = s.data as List<dynamic>;
          if (items.isEmpty) return const Empty("No notifications");
          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __)=> const Divider(height: 1),
            itemBuilder: (ctx, i){
              final x = items[i] as Map<String, dynamic>;
              return ListTile(
                title: Text(x['type'] ?? 'notification'),
                subtitle: Text((x['payload'] ?? {}).toString()),
              );
            },
          );
        },
      ),
    );
  }
}

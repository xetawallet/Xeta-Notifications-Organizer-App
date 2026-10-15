import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'crypto_donation_page.dart';

final ValueNotifier<ThemeMode> appThemeMode = ValueNotifier(ThemeMode.dark);

void main() => runApp(const App());

enum Status { all, read, unread }

enum MainView { notifications, starred, details }

class N {
  N(Map m)
    : id = m['id'] ?? '',
      app = m['appName'] ?? '',
      pkg = m['packageName'] ?? '',
      title = m['title'] ?? '',
      body = m['body'] ?? '',
      date = m['date'] ?? '',
      iconPath = m['iconPath'] ?? '',
      key = m['key'] ?? '',
      tag = m['tag'] ?? '',
      channelId = m['channelId'] ?? '',
      category = m['category'] ?? '',
      groupKey = m['groupKey'] ?? '',
      shortcutId = m['shortcutId'] ?? '',
      creatorPackage = m['creatorPackage'] ?? '',
      link = m['link'] ?? '',
      actionKind = m['actionKind'] ?? '',
      notificationId = m['notificationId'] ?? 0,
      color = Color((m['color'] as int? ?? 0xff2563eb) | 0xff000000),
      time = DateTime.fromMillisecondsSinceEpoch(m['time'] ?? 0),
      read = m['read'] == true,
      starred = m['starred'] == true;
  final String id,
      app,
      pkg,
      title,
      body,
      date,
      iconPath,
      key,
      tag,
      channelId,
      category,
      groupKey,
      shortcutId,
      creatorPackage,
      link,
      actionKind;
  final int notificationId;
  final Color color;
  final DateTime time;
  bool read, starred;
}

class Native {
  static const c = MethodChannel('xeta_notifications');
  static Future<List<N>> all() async =>
      ((await c.invokeMethod('notifications')) as List)
          .map((e) => N(Map.from(e)))
          .toList();
  static Future<bool> flag(String id, String f, bool v) async =>
      await c.invokeMethod('setFlag', {'id': id, 'flag': f, 'value': v}) ==
      true;
  static Future<bool> readMany(List<N> ns, bool v) async =>
      await c.invokeMethod('setReadMany', {
        'ids': ns.map((n) => n.id).toList(),
        'value': v,
      }) ==
      true;
  static Future<bool> open(String id) async =>
      await c.invokeMethod('openNotification', {'id': id}) == true;
  static Future<List<String>> repetitiveApps() async =>
      List<String>.from(await c.invokeMethod('repetitiveApps') as List);
  static Future<void> setRepetitiveApps(Set<String> apps) async =>
      c.invokeMethod('setRepetitiveApps', {'apps': apps.toList()});
  static Future<bool> privacyConsent() async =>
      await c.invokeMethod('privacyConsent') == true;
  static Future<void> setPrivacyConsent(bool value) async =>
      c.invokeMethod('setPrivacyConsent', {'value': value});
  static Future<bool> clearNotifications() async =>
      await c.invokeMethod('clearNotifications') == true;
  static Future<int> deleteGroups(String type, List<String> values) async =>
      await c.invokeMethod('deleteGroups', {'type': type, 'values': values})
          as int;
  static Future<bool> darkMode() async =>
      await c.invokeMethod('darkMode') == true;
  static Future<void> setDarkMode(bool value) async =>
      c.invokeMethod('setDarkMode', {'value': value});
}

const privacyPolicyText =
    'Xeta Notifications Organizer uses Android notification access to read notification titles, text, app names, package names, times, icons, and tap actions. It stores them in private storage on this device to organize, mark, and reopen notifications. The app also reads the names of launcher apps so you can select important and repetitive apps; your selections are stored on this device. The app does not send this information to a server or share it. An optional donation screen displays public cryptocurrency addresses and QR codes and can copy an address; the app does not access a wallet, initiate transactions, or receive transaction details. External wallet apps apply their own privacy practices. You can stop future collection by disabling Notification access in Android settings and remove saved notification records from Settings. Uninstalling removes the app data according to Android system behavior. For privacy questions, contact the developer through the contact address on the Google Play listing.';

class App extends StatefulWidget {
  const App({super.key});
  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  @override
  void initState() {
    super.initState();
    Native.darkMode().then((dark) {
      appThemeMode.value = dark ? ThemeMode.dark : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<ThemeMode>(
    valueListenable: appThemeMode,
    builder: (context, mode, _) => MaterialApp(
      title: 'Xeta Notifications Organizer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff2563eb)),
        useMaterial3: true,
        cardTheme: const CardThemeData(elevation: .5),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xff2563eb),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        cardTheme: const CardThemeData(elevation: .5),
      ),
      themeMode: mode,
      home: const Gate(),
    ),
  );
}

class Gate extends StatefulWidget {
  const Gate({super.key});
  @override
  State<Gate> createState() => _GateState();
}

class _GateState extends State<Gate> {
  bool? done, consent;
  @override
  void initState() {
    super.initState();
    Future.wait([
      Native.c.invokeMethod('onboarded'),
      Native.privacyConsent(),
    ]).then((values) {
      if (mounted) {
        setState(() {
          done = values[0] == true;
          consent = values[1] == true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) => done == null || consent == null
      ? const Scaffold(body: Center(child: CircularProgressIndicator()))
      : !consent!
      ? PrivacyConsent(
          onAgree: () async {
            await Native.setPrivacyConsent(true);
            if (mounted) setState(() => consent = true);
          },
        )
      : done!
      ? const Home()
      : Onboarding(onDone: () => setState(() => done = true));
}

class PrivacyConsent extends StatefulWidget {
  const PrivacyConsent({super.key, required this.onAgree});
  final VoidCallback onAgree;
  @override
  State<PrivacyConsent> createState() => _PrivacyConsentState();
}

class _PrivacyConsentState extends State<PrivacyConsent> {
  bool agreed = false;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Your notification data')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Icon(Icons.privacy_tip_outlined, size: 52),
          const SizedBox(height: 20),
          Text(
            'How notification access is used',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          const Text(
            'Xeta Notifications Organizer reads notification titles, text, app names, package names, times, icons, and original tap actions from apps on this device. It stores this information in private app storage so you can organize notifications, mark them read, and reopen their original action. This can happen while the app is closed after you enable Android notification access. The app also reads launcher app names so you can choose important and repetitive apps; those selections stay on this device. This information is not sent to our servers or shared. When silence is enabled, non-important notifications are archived and removed from the notification shade.',
          ),
          const SizedBox(height: 12),
          const Text(
            'You can stop collection by turning off Notification access in Android settings. You can remove stored records from Settings. Read the Privacy Policy there for more information.',
          ),
          TextButton.icon(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Privacy Policy'),
                content: SingleChildScrollView(child: Text(privacyPolicyText)),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
            icon: const Icon(Icons.policy_outlined),
            label: const Text('Read Privacy Policy'),
          ),
          const SizedBox(height: 18),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: agreed,
            onChanged: (value) => setState(() => agreed = value == true),
            title: const Text('I understand and agree'),
            controlAffinity: ListTileControlAffinity.leading,
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: agreed ? widget.onAgree : null,
            child: const Text('Agree and continue'),
          ),
        ],
      ),
    ),
  );
}

class Onboarding extends StatefulWidget {
  const Onboarding({super.key, required this.onDone});
  final VoidCallback onDone;
  @override
  State<Onboarding> createState() => _OnboardingState();
}

class _OnboardingState extends State<Onboarding> with WidgetsBindingObserver {
  final pc = PageController();
  int i = 0;
  bool restricted = false, appNotifs = false, access = false, silence = true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    refresh();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) refresh();
  }

  Future<void> refresh() async {
    final r = await Future.wait([
      Native.c.invokeMethod('restrictedDone'),
      Native.c.invokeMethod('appNotificationsEnabled'),
      Native.c.invokeMethod('listenerEnabled'),
      Native.c.invokeMethod('silenceNonImportant'),
    ]);
    if (mounted) {
      setState(() {
        restricted = r[0] == true;
        appNotifs = r[1] == true;
        access = r[2] == true;
        silence = r[3] == true;
      });
    }
  }

  Future<void> finish() async {
    await Native.c.invokeMethod('setOnboarded', {'value': true});
    widget.onDone();
  }

  Future<void> setSilence(bool v) async {
    await Native.c.invokeMethod('setSilenceNonImportant', {'value': v});
    await refresh();
  }

  Future<void> markRestricted(bool v) async {
    await Native.c.invokeMethod('setRestrictedDone', {'value': v});
    if (v) await Native.c.invokeMethod('openAppSettings');
    await refresh();
  }

  Future<void> toggleTheme() async {
    final dark = appThemeMode.value != ThemeMode.dark;
    appThemeMode.value = dark ? ThemeMode.dark : ThemeMode.light;
    await Native.setDarkMode(dark);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Getting started'),
      actions: [
        IconButton(
          tooltip: appThemeMode.value == ThemeMode.dark
              ? 'Switch to light theme'
              : 'Switch to dark theme',
          onPressed: toggleTheme,
          icon: Icon(
            appThemeMode.value == ThemeMode.dark
                ? Icons.light_mode_outlined
                : Icons.dark_mode_outlined,
          ),
        ),
      ],
    ),
    body: SafeArea(
      child: Column(
        children: [
          Expanded(
            child: PageView(
              controller: pc,
              onPageChanged: (v) => setState(() => i = v),
              children: [
                page(
                  Icons.swipe,
                  'Fast triage',
                  'Group busy apps, open original actions, and swipe only when changing read state.',
                  [
                    SwitchListTile(
                      value: silence,
                      onChanged: setSilence,
                      title: const Text('Silence non-important apps'),
                    ),
                  ],
                ),
                page(
                  Icons.admin_panel_settings,
                  'Restricted settings',
                  restricted
                      ? 'Updated'
                      : 'Allow unrestricted background access if Android blocks capture.',
                  [
                    SwitchListTile(
                      value: restricted,
                      onChanged: markRestricted,
                      title: const Text('Restricted settings'),
                    ),
                    FilledButton.icon(
                      onPressed: () => Native.c.invokeMethod('openAppSettings'),
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('Open'),
                    ),
                  ],
                ),
                page(
                  Icons.notifications,
                  'Notification settings',
                  appNotifs
                      ? 'Updated'
                      : 'Keep app notifications enabled and grant listener access.',
                  [
                    SwitchListTile(
                      value: appNotifs,
                      onChanged: (_) =>
                          Native.c.invokeMethod('openAppNotificationSettings'),
                      title: const Text('Notification setting'),
                    ),
                    SwitchListTile(
                      value: access,
                      onChanged: (_) =>
                          Native.c.invokeMethod('openListenerSettings'),
                      title: const Text('Notification access'),
                    ),
                  ],
                ),
                page(
                  Icons.repeat,
                  'Repetitive apps',
                  'Choose apps whose notifications should still be recorded but start as read. You can change this any time in Settings.',
                  [
                    OutlinedButton.icon(
                      onPressed: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const SettingsPage(initialTab: 2),
                          ),
                        );
                        await refresh();
                      },
                      icon: const Icon(Icons.tune),
                      label: const Text('Choose repetitive apps'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text('${i + 1}/4'),
                const Spacer(),
                TextButton(
                  onPressed: finish,
                  child: const Text('Skip for now'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: i == 3
                      ? finish
                      : () => pc.nextPage(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOut,
                        ),
                  child: Text(i == 3 ? 'Start' : 'Next'),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
  Widget page(IconData icon, String title, String text, List<Widget> actions) =>
      Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(radius: 44, child: Icon(icon, size: 42)),
            const SizedBox(height: 24),
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 10),
            Text(
              text,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 18),
            ...actions,
          ],
        ),
      );
}

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> with WidgetsBindingObserver {
  var items = <N>[],
      status = Status.unread,
      day = DateTime.now(),
      view = MainView.notifications,
      loading = true,
      enabled = false;
  var modes = {'notifications': 'all', 'starred': 'all', 'details': 'all'};
  var openDates = <String>{};
  var dateExpansionInitialized = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    load();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) load();
  }

  String ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  String get key => view.name;
  bool get calendar => modes[key] == 'calendar';
  bool ok(N n) =>
      (status == Status.all || (status == Status.read ? n.read : !n.read)) &&
      (view != MainView.starred || n.starred) &&
      (!calendar || n.date == ymd(day));
  Future<void> load() async {
    final r = await Future.wait([
      Native.all(),
      Native.c.invokeMethod('listenerEnabled'),
      Native.c.invokeMethod('viewMode', {'key': 'notifications'}),
      Native.c.invokeMethod('viewMode', {'key': 'starred'}),
      Native.c.invokeMethod('viewMode', {'key': 'details'}),
    ]);
    if (mounted) {
      setState(() {
        items = r[0] as List<N>;
        if (!dateExpansionInitialized && items.isNotEmpty) {
          // A new app session opens only the newest date. Subsequent reloads
          // (including marking an item read) retain the user's date choices.
          openDates = items.isEmpty ? <String>{} : {items.first.date};
          dateExpansionInitialized = true;
        }
        enabled = r[1] == true;
        modes = {
          'notifications': r[2] as String,
          'starred': r[3] as String,
          'details': r[4] as String,
        };
        loading = false;
      });
    }
  }

  Future<void> setRead(List<N> ns, bool v) async {
    await Native.readMany(ns, v);
    await load();
  }

  Future<void> confirmReadDate(String date) async {
    final unread = items.where((n) => n.date == date && !n.read).toList();
    if (unread.isEmpty) return;
    var confirmed = false;
    final shouldRead = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, updateDialog) => AlertDialog(
          title: const Text('Mark this day as read?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This will mark ${unread.length} unread notifications from $date as read, across all apps.',
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: confirmed,
                onChanged: (value) =>
                    updateDialog(() => confirmed = value == true),
                title: const Text(
                  'I reviewed the day and want to mark all as read',
                ),
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: confirmed
                  ? () => Navigator.pop(dialogContext, true)
                  : null,
              child: const Text('Yes, mark read'),
            ),
          ],
        ),
      ),
    );
    if (shouldRead == true && mounted) await setRead(unread, true);
  }

  Future<void> setFlag(N n, String f, bool v) async {
    await Native.flag(n.id, f, v);
    await load();
  }

  @override
  Widget build(BuildContext context) {
    final shown = items.where(ok).toList();
    final unread = items
        .where(
          (n) =>
              !n.read &&
              (view != MainView.starred || n.starred) &&
              (!calendar || n.date == ymd(day)),
        )
        .length;
    return Scaffold(
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            children: [
              nav('Notifications', Icons.notifications, MainView.notifications),
              nav('Starred', Icons.star, MainView.starred),
              nav('Details', Icons.list_alt, MainView.details),
              const Spacer(),
              ListTile(
                title: const Text('Settings'),
                leading: const Icon(Icons.settings),
                onTap: () {
                  Navigator.pop(context);
                  openSettings();
                },
              ),
            ],
          ),
        ),
      ),
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: 'Select notifications to delete',
            onPressed: items.isEmpty ? null : selectForDeletion,
            icon: const Icon(Icons.checklist),
          ),
          IconButton(onPressed: openSettings, icon: const Icon(Icons.settings)),
          IconButton(onPressed: load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (!enabled)
                  ListTile(
                    tileColor: Theme.of(context).colorScheme.tertiaryContainer,
                    leading: const Icon(Icons.notifications_active),
                    title: const Text('Enable notification access'),
                    onTap: () => Native.c.invokeMethod('openListenerSettings'),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
                  child: Row(
                    children: [
                      IconButton.filledTonal(
                        onPressed: calendar ? pickDay : null,
                        icon: const Icon(Icons.calendar_month),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          calendar
                              ? '${ymd(day)}  -  $unread unread'
                              : '$unread unread',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      DropdownButton<Status>(
                        value: status,
                        underline: const SizedBox(),
                        onChanged: (v) => setState(() => status = v!),
                        items: const [
                          DropdownMenuItem(
                            value: Status.all,
                            child: Text('All'),
                          ),
                          DropdownMenuItem(
                            value: Status.read,
                            child: Text('Read'),
                          ),
                          DropdownMenuItem(
                            value: Status.unread,
                            child: Text('Unread'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: shown.isEmpty
                      ? const Center(child: Text('No notifications'))
                      : content(shown),
                ),
              ],
            ),
    );
  }

  String get title => switch (view) {
    MainView.notifications => 'Notifications',
    MainView.starred => 'Starred',
    MainView.details => 'Details',
  };
  ListTile nav(String label, IconData icon, MainView v) => ListTile(
    title: Text(label),
    leading: Icon(icon),
    selected: view == v,
    onTap: () {
      setState(() => view = v);
      Navigator.pop(context);
    },
  );
  Future<void> openSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SettingsPage()),
    );
    await load();
  }

  Future<void> selectForDeletion() async {
    final deleted = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => NotificationSelectionPage(items: items),
      ),
    );
    if (deleted == true) await load();
  }

  Future<void> pickDay() async {
    final d = await showDatePicker(
      context: context,
      initialDate: day,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (d != null) setState(() => day = d);
  }

  Widget content(List<N> data) => calendar ? appGroups(data) : dateGroups(data);

  Widget dateGroups(List<N> data) {
    final g = <String, List<N>>{};
    for (final n in data) {
      g.putIfAbsent(n.date, () => []).add(n);
    }
    final keys = g.keys.toList()..sort((a, b) => b.compareTo(a));
    return ListView(
      padding: const EdgeInsets.all(12),
      children: keys.map((d) {
        final group = g[d]!;
        final unreadCount = items.where((n) => n.date == d && !n.read).length;
        return swipe(
          group,
          Card(
            child: ExpansionTile(
              key: PageStorageKey('date-$d'),
              initiallyExpanded: openDates.contains(d),
              onExpansionChanged: (open) =>
                  setState(() => open ? openDates.add(d) : openDates.remove(d)),
              leading: const Icon(Icons.calendar_today_outlined),
              title: Text(d),
              subtitle: Text('${group.length} shown  ·  $unreadCount unread'),
              children: [const Divider(height: 1), ...groupCards(group)],
            ),
          ),
          dateKey: d,
        );
      }).toList(),
    );
  }

  Widget appGroups(List<N> data) =>
      ListView(padding: const EdgeInsets.all(12), children: groupCards(data));
  List<Widget> groupCards(List<N> data) {
    final g = <String, List<N>>{};
    for (final n in data) {
      g.putIfAbsent(n.pkg, () => []).add(n);
    }
    final keys = g.keys.toList()
      ..sort(
        (a, b) => g[a]!.first.app.toLowerCase().compareTo(
          g[b]!.first.app.toLowerCase(),
        ),
      );
    return keys.map((k) => groupCard(g[k]!)).toList();
  }

  Widget groupCard(List<N> group) {
    final a = group.first, unread = group.where((n) => !n.read).length;
    return swipe(
      group,
      Card(
        child: ExpansionTile(
          initiallyExpanded: group.length < 4,
          leading: appIcon(a, 22),
          title: Text(a.app),
          subtitle: Text('${group.length} notifications  ·  $unread unread'),
          children: group.map(card).toList(),
        ),
      ),
    );
  }

  Widget swipe(List<N> ns, Widget child, {String? dateKey}) => Dismissible(
    key: ValueKey('g-${ns.map((n) => n.id).join()}'),
    direction: DismissDirection.horizontal,
    confirmDismiss: (d) async {
      if (d == DismissDirection.startToEnd && dateKey != null) {
        await confirmReadDate(dateKey);
      } else {
        await setRead(ns, d == DismissDirection.startToEnd);
      }
      return false;
    },
    background: swipeBg(true),
    secondaryBackground: swipeBg(false),
    child: child,
  );
  Widget swipeBg(bool read) => Container(
    alignment: read ? Alignment.centerLeft : Alignment.centerRight,
    padding: EdgeInsets.only(left: read ? 24 : 0, right: read ? 0 : 24),
    color: read ? Colors.green : Colors.orange,
    child: Icon(
      read ? Icons.done : Icons.mark_email_unread,
      color: Colors.white,
    ),
  );
  Widget card(N n) => Dismissible(
    key: ValueKey(n.id),
    direction: DismissDirection.horizontal,
    confirmDismiss: (d) async {
      await setRead([n], d == DismissDirection.startToEnd);
      return false;
    },
    background: swipeBg(true),
    secondaryBackground: swipeBg(false),
    child: ListTile(
      leading: appIcon(n, 18),
      title: Text(
        n.title.isEmpty ? n.app : n.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: n.read
              ? Theme.of(context).colorScheme.onSurfaceVariant
              : Theme.of(context).colorScheme.onSurface,
          fontWeight: n.read ? FontWeight.w400 : FontWeight.w600,
        ),
      ),
      subtitle: Text(
        view == MainView.details ? '${n.app}  ·  ${n.body}' : n.body,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: n.read
              ? Theme.of(context).colorScheme.onSurfaceVariant
              : Theme.of(context).colorScheme.onSurface,
        ),
      ),
      trailing: IconButton(
        icon: Icon(
          n.starred ? Icons.star : Icons.star_border,
          color: n.starred ? Colors.amber.shade700 : null,
        ),
        onPressed: () => setFlag(n, 'starred', !n.starred),
      ),
      onTap: view == MainView.details
          ? () => showMeta(n)
          : () async {
              final opened = await Native.open(n.id);
              if (!opened && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('No stored action available')),
                );
              }
            },
    ),
  );
  String _actionLabel(String kind) => switch (kind) {
    'pendingIntent' => 'Open Action',
    'link' => 'Web link',
    'openApp' => 'Open app',
    _ => 'Unavailable',
  };

  Future<void> openAction(N n) async {
    final opened = await Native.open(n.id);
    if (!mounted) return;
    if (opened) {
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This notification action is no longer available'),
        ),
      );
    }
  }

  Future<void> showMeta(N n) async => showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(n.app),
      content: SizedBox(
        width: double.maxFinite,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .58,
          ),
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: [
              ('title', n.title),
              ('body', n.body),
              ('package', n.pkg),
              ('tapAction', _actionLabel(n.actionKind)),
              ('link', n.link),
              ('creatorPackage', n.creatorPackage),
              ('channelId', n.channelId),
              ('category', n.category),
              ('groupKey', n.groupKey),
              ('shortcutId', n.shortcutId),
              ('notificationId', '${n.notificationId}'),
              ('tag', n.tag),
              ('key', n.key),
              ('time', n.time.toIso8601String()),
            ].length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (_, index) {
              final fields = [
                ('title', n.title),
                ('body', n.body),
                ('package', n.pkg),
                ('tapAction', _actionLabel(n.actionKind)),
                ('link', n.link),
                ('creatorPackage', n.creatorPackage),
                ('channelId', n.channelId),
                ('category', n.category),
                ('groupKey', n.groupKey),
                ('shortcutId', n.shortcutId),
                ('notificationId', '${n.notificationId}'),
                ('tag', n.tag),
                ('key', n.key),
                ('time', n.time.toIso8601String()),
              ];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${fields[index].$1}:',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 3),
                    SelectableText(fields[index].$2),
                  ],
                ),
              );
            },
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        FilledButton(
          onPressed: () => openAction(n),
          child: const Text('Open action'),
        ),
      ],
    ),
  );
}

enum DeleteGrouping { day, app, notification }

class NotificationSelectionPage extends StatefulWidget {
  const NotificationSelectionPage({super.key, required this.items});
  final List<N> items;

  @override
  State<NotificationSelectionPage> createState() =>
      _NotificationSelectionPageState();
}

class _NotificationSelectionPageState extends State<NotificationSelectionPage> {
  DeleteGrouping grouping = DeleteGrouping.day;
  final selected = <String>{};
  bool deleting = false;

  Map<String, List<N>> get groups {
    final result = <String, List<N>>{};
    for (final item in widget.items) {
      final key = switch (grouping) {
        DeleteGrouping.day => item.date,
        DeleteGrouping.app => item.pkg,
        DeleteGrouping.notification => item.id,
      };
      result.putIfAbsent(key, () => []).add(item);
    }
    return result;
  }

  String labelFor(String key, List<N> values) => switch (grouping) {
    DeleteGrouping.day => key,
    DeleteGrouping.app => values.first.app,
    DeleteGrouping.notification =>
      values.first.title.isEmpty ? values.first.app : values.first.title,
  };

  Future<void> deleteSelected() async {
    if (selected.isEmpty || deleting) return;
    final count = widget.items
        .where((n) => selected.contains(_valueFor(n)))
        .length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete selected notifications?'),
        content: Text(
          'This permanently removes $count saved notifications from this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => deleting = true);
    try {
      final removed = await Native.deleteGroups(
        grouping.name,
        selected.toList(),
      );
      if (mounted) Navigator.pop(context, removed > 0);
    } on PlatformException {
      if (mounted) {
        setState(() => deleting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not delete selected notifications'),
          ),
        );
      }
    }
  }

  String _valueFor(N n) => switch (grouping) {
    DeleteGrouping.day => n.date,
    DeleteGrouping.app => n.pkg,
    DeleteGrouping.notification => n.id,
  };

  @override
  Widget build(BuildContext context) {
    final grouped = groups;
    final keys = grouped.keys.toList();
    if (grouping == DeleteGrouping.day) {
      keys.sort((a, b) => b.compareTo(a));
    } else {
      keys.sort(
        (a, b) => labelFor(
          a,
          grouped[a]!,
        ).toLowerCase().compareTo(labelFor(b, grouped[b]!).toLowerCase()),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select to delete'),
        actions: [
          TextButton(
            onPressed: deleting || keys.isEmpty
                ? null
                : () => setState(() {
                    if (selected.length == keys.length) {
                      selected.clear();
                    } else {
                      selected
                        ..clear()
                        ..addAll(keys);
                    }
                  }),
            child: Text(selected.length == keys.length ? 'Clear' : 'All'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: SegmentedButton<DeleteGrouping>(
              segments: const [
                ButtonSegment(value: DeleteGrouping.day, label: Text('Day')),
                ButtonSegment(value: DeleteGrouping.app, label: Text('App')),
                ButtonSegment(
                  value: DeleteGrouping.notification,
                  label: Text('Notification'),
                ),
              ],
              selected: {grouping},
              onSelectionChanged: deleting
                  ? null
                  : (value) => setState(() {
                      grouping = value.first;
                      selected.clear();
                    }),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: keys.length,
              itemBuilder: (context, index) {
                final key = keys[index];
                final values = grouped[key]!;
                final checked = selected.contains(key);
                final subtitle = switch (grouping) {
                  DeleteGrouping.day => '${values.length} notifications',
                  DeleteGrouping.app => '${values.length} notifications',
                  DeleteGrouping.notification =>
                    '${values.first.app}  ·  ${values.first.date}',
                };
                return CheckboxListTile(
                  value: checked,
                  title: Text(
                    labelFor(key, values),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  secondary: grouping == DeleteGrouping.notification
                      ? appIcon(values.first, 18)
                      : null,
                  onChanged: deleting
                      ? null
                      : (value) => setState(() {
                          if (value == true) {
                            selected.add(key);
                          } else {
                            selected.remove(key);
                          }
                        }),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: selected.isEmpty || deleting
                      ? null
                      : deleteSelected,
                  icon: deleting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.delete_outline),
                  label: Text(
                    deleting
                        ? 'Deleting…'
                        : 'Delete selected (${selected.length})',
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Widget appIcon(N n, double r) => CircleAvatar(
  radius: r,
  backgroundColor: n.color.withValues(alpha: .14),
  child: n.iconPath.isNotEmpty && File(n.iconPath).existsSync()
      ? ClipOval(
          child: Image.file(
            File(n.iconPath),
            width: r * 1.45,
            height: r * 1.45,
          ),
        )
      : Icon(Icons.notifications, color: n.color, size: r),
);

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, this.initialTab = 0});
  final int initialTab;
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage>
    with WidgetsBindingObserver {
  var tab = 0,
      apps = <Map>[],
      selected = <String>{},
      repetitive = <String>{},
      modes = {'notifications': 'all', 'starred': 'all', 'details': 'all'},
      silence = true,
      darkMode = true,
      q = '',
      access = false,
      appNotifs = false,
      restricted = false;
  @override
  void initState() {
    super.initState();
    tab = widget.initialTab;
    WidgetsBinding.instance.addObserver(this);
    init();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) init();
  }

  Future<void> init() async {
    final r = await Future.wait([
      Native.c.invokeMethod('installedApps'),
      Native.c.invokeMethod('importantApps'),
      Native.repetitiveApps(),
      Native.c.invokeMethod('silenceNonImportant'),
      Native.c.invokeMethod('listenerEnabled'),
      Native.c.invokeMethod('appNotificationsEnabled'),
      Native.c.invokeMethod('restrictedDone'),
      Native.c.invokeMethod('viewMode', {'key': 'notifications'}),
      Native.c.invokeMethod('viewMode', {'key': 'starred'}),
      Native.c.invokeMethod('viewMode', {'key': 'details'}),
      Native.darkMode(),
    ]);
    if (mounted) {
      setState(() {
        apps = List<Map>.from(r[0] as List);
        selected = Set<String>.from(r[1] as List);
        repetitive = Set<String>.from(r[2] as List);
        silence = r[3] == true;
        access = r[4] == true;
        appNotifs = r[5] == true;
        restricted = r[6] == true;
        modes = {
          'notifications': r[7] as String,
          'starred': r[8] as String,
          'details': r[9] as String,
        };
        darkMode = r[10] == true;
      });
    }
  }

  Future<void> save() async {
    await Native.c.invokeMethod('setImportantApps', {
      'apps': selected.toList(),
    });
    await Native.c.invokeMethod('setSilenceNonImportant', {'value': silence});
  }

  Future<void> setMode(String key, String value) async {
    await Native.c.invokeMethod('setViewMode', {'key': key, 'value': value});
    await init();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Settings')),
    body: Column(
      children: [
        Material(
          color: Theme.of(context).colorScheme.surface,
          child: Row(
            children: [
              fixedTab(0, 'App'),
              fixedTab(1, 'Important apps'),
              fixedTab(2, 'Repetitive apps'),
            ],
          ),
        ),
        Expanded(child: tab == 0 ? appSettings() : appSelectionList()),
      ],
    ),
  );
  Widget fixedTab(int i, String label) => Expanded(
    child: InkWell(
      onTap: () => setState(() => tab = i),
      child: Container(
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              width: tab == i ? 3 : 1,
              color: tab == i
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).dividerColor,
            ),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: tab == i ? FontWeight.w700 : FontWeight.w500,
            color: tab == i ? Theme.of(context).colorScheme.primary : null,
          ),
        ),
      ),
    ),
  );
  Widget appSettings() => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      SwitchListTile(
        title: const Text('Dark theme'),
        subtitle: Text(darkMode ? 'On' : 'Off'),
        value: darkMode,
        onChanged: (value) async {
          setState(() => darkMode = value);
          appThemeMode.value = value ? ThemeMode.dark : ThemeMode.light;
          await Native.setDarkMode(value);
        },
      ),
      ListTile(
        leading: const Icon(Icons.volunteer_activism_outlined),
        title: const Text('Help us! / Donate'),
        subtitle: const Text('Support development with an optional donation.'),
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const DonationPage())),
      ),
      const Divider(height: 28),
      SwitchListTile(
        value: access,
        onChanged: (_) => Native.c.invokeMethod('openListenerSettings'),
        title: const Text('Notification access'),
      ),
      SwitchListTile(
        value: appNotifs,
        onChanged: (_) => Native.c.invokeMethod('openAppNotificationSettings'),
        title: const Text('Notification setting'),
      ),
      SwitchListTile(
        value: restricted,
        onChanged: (v) async {
          await Native.c.invokeMethod('setRestrictedDone', {'value': v});
          if (v) await Native.c.invokeMethod('openAppSettings');
          await init();
        },
        title: const Text('Restricted setting'),
      ),
      SwitchListTile(
        title: const Text('Silence non-important apps'),
        subtitle: const Text('Important apps still show in notification bar'),
        value: silence,
        onChanged: (v) async {
          setState(() => silence = v);
          await save();
        },
      ),
      const Divider(height: 28),
      ListTile(
        leading: const Icon(Icons.privacy_tip_outlined),
        title: const Text('Privacy Policy'),
        subtitle: const Text('Review how notification information is used.'),
        onTap: () => showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Privacy Policy'),
            content: SingleChildScrollView(child: Text(privacyPolicyText)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      ),
      ListTile(
        leading: const Icon(Icons.delete_outline),
        title: const Text('Delete stored notifications'),
        subtitle: const Text(
          'Remove all notification records from this device.',
        ),
        onTap: () async {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Delete stored notifications?'),
              content: const Text(
                'This permanently removes every saved notification from this device.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Delete all'),
                ),
              ],
            ),
          );
          if (confirmed == true) {
            await Native.clearNotifications();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Stored notifications deleted')),
              );
            }
          }
        },
      ),
      const Divider(height: 28),
      viewModeTile('Notification grouping', 'notifications'),
      viewModeTile('Starred grouping', 'starred'),
      viewModeTile('Details grouping', 'details'),
    ],
  );
  Widget viewModeTile(String title, String key) => ListTile(
    title: Text(title),
    trailing: DropdownButton<String>(
      value: modes[key] ?? 'all',
      underline: const SizedBox(),
      items: const [
        DropdownMenuItem(value: 'all', child: Text('All')),
        DropdownMenuItem(value: 'calendar', child: Text('App-wise view')),
      ],
      onChanged: (v) => setMode(key, v ?? 'all'),
    ),
  );
  Widget appSelectionList() {
    final importantTab = tab == 1;
    final chosen = importantTab ? selected : repetitive;
    final shown =
        apps
            .where(
              (a) => '${a['appName']} ${a['packageName']}'
                  .toLowerCase()
                  .contains(q.toLowerCase()),
            )
            .toList()
          ..sort((a, b) {
            final aSelected = chosen.contains(a['packageName']);
            final bSelected = chosen.contains(b['packageName']);
            if (aSelected != bSelected) return aSelected ? -1 : 1;
            return (a['appName'] as String).toLowerCase().compareTo(
              (b['appName'] as String).toLowerCase(),
            );
          });
    final selectedShown = shown
        .where((a) => chosen.contains(a['packageName']))
        .toList();
    final unselectedShown = shown
        .where((a) => !chosen.contains(a['packageName']))
        .toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Search apps',
            ),
            onChanged: (v) => setState(() => q = v),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              importantTab
                  ? 'Notifications from important apps stay in your notification shade when silence is on.'
                  : 'Recorded as usual, with new notifications marked read automatically.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ),
        Expanded(
          child: shown.isEmpty
              ? const Center(child: Text('No apps found'))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                  children: [
                    appSectionHeader(
                      'Selected apps',
                      selectedShown.length,
                      true,
                    ),
                    ...selectedShown.map(appSelectionTile),
                    appSectionHeader(
                      'Not selected',
                      unselectedShown.length,
                      false,
                    ),
                    ...unselectedShown.map(appSelectionTile),
                  ],
                ),
        ),
      ],
    );
  }

  Widget appSectionHeader(String title, int count, bool isSelected) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
    child: Row(
      children: [
        Icon(
          isSelected ? Icons.check_circle_outline : Icons.circle_outlined,
          size: 18,
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(width: 6),
        Text('$count', style: Theme.of(context).textTheme.labelMedium),
      ],
    ),
  );

  Widget appSelectionTile(Map app) {
    final importantTab = tab == 1;
    final pkg = app['packageName'] as String;
    final on = (importantTab ? selected : repetitive).contains(pkg);
    final icon = app['iconPath'] as String? ?? '';
    return Card(
      color: on ? Theme.of(context).colorScheme.secondaryContainer : null,
      margin: const EdgeInsets.symmetric(vertical: 3),
      child: CheckboxListTile(
        value: on,
        selected: on,
        secondary: icon.isNotEmpty && File(icon).existsSync()
            ? Image.file(File(icon), width: 32, height: 32)
            : const Icon(Icons.apps),
        title: Text(app['appName'] as String),
        subtitle: Text(pkg),
        onChanged: (v) async {
          if (importantTab) {
            setState(
              () => v == true ? selected.add(pkg) : selected.remove(pkg),
            );
            await save();
          } else {
            setState(
              () => v == true ? repetitive.add(pkg) : repetitive.remove(pkg),
            );
            await Native.setRepetitiveApps(repetitive);
          }
        },
      ),
    );
  }
}

class DonationPage extends StatefulWidget {
  const DonationPage({super.key});

  @override
  State<DonationPage> createState() => _DonationPageState();
}

class _DonationPageState extends State<DonationPage> {
  late final Future<List<DonationWallet>> wallets = loadWallets();

  Future<List<DonationWallet>> loadWallets() async {
    final decoded =
        jsonDecode(await rootBundle.loadString('assets/donation_wallets.json'))
            as Map<String, dynamic>;
    return (decoded['donations'] as List<dynamic>)
        .map(
          (entry) => DonationWallet(
            currency: entry['currency'] as String,
            network: entry['network'] as String,
            address: entry['address'] as String,
          ),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<DonationWallet>>(
    future: wallets,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Scaffold(
          appBar: AppBar(title: const Text('Help us! / Donate')),
          body: const Center(child: Text('Donation details are unavailable.')),
        );
      }
      if (!snapshot.hasData) {
        return Scaffold(
          appBar: AppBar(title: const Text('Help us! / Donate')),
          body: const Center(child: CircularProgressIndicator()),
        );
      }
      return CryptoDonationPage(
        wallets: snapshot.data!,
        message: 'Support Xeta Notifications Organizer development.',
      );
    },
  );
}

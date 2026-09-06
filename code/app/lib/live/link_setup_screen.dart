import 'package:flutter/material.dart';

import 'live_store.dart';

/// Early laptop-relay entry. Shown right after the Start gate so a caregiver
/// can type the laptop LAN IP before Setup/calibration. Skippable for an
/// offline phone-only rehearsal. Does not connect yet — Live screen still
/// joins the room later.
class LinkSetupScreen extends StatefulWidget {
  const LinkSetupScreen({
    super.key,
    required this.onContinue,
  });

  final VoidCallback onContinue;

  @override
  State<LinkSetupScreen> createState() => _LinkSetupScreenState();
}

class _LinkSetupScreenState extends State<LinkSetupScreen> {
  final _host = TextEditingController();
  final _room = TextEditingController(text: LiveStore.defaultRoom);
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final saved = await LiveStore.loadLink();
    if (!mounted) return;
    setState(() {
      _host.text = saved.host;
      _room.text = saved.room;
      _loading = false;
    });
  }

  Future<void> _saveAndContinue({required bool requireHost}) async {
    final host = _host.text.trim();
    final room = _room.text.trim().isEmpty
        ? LiveStore.defaultRoom
        : _room.text.trim();
    if (requireHost && host.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Enter the laptop IP (or Skip for phone-only demo).',
          ),
        ),
      );
      return;
    }
    await LiveStore.saveLink(
      host: host,
      room: room,
    );
    if (!mounted) return;
    widget.onContinue();
  }

  @override
  void dispose() {
    _host.dispose();
    _room.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      key: const Key('link-setup'),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
                children: [
                  Text(
                    'Laptop relay',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'On the laptop run npm run relay in code/desktop, then '
                    'open http://<this-ip>:7777/rail.html. Enter that same '
                    'IP here so the phone can join later from Live.',
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      height: 1.4,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 22),
                  TextField(
                    key: const Key('link-host'),
                    controller: _host,
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      labelText: 'Laptop IP / relay host',
                      hintText: LiveStore.hostHint,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const Key('link-room'),
                    controller: _room,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Room',
                      hintText: LiveStore.defaultRoom,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 64,
                    child: FilledButton(
                      key: const Key('link-continue'),
                      onPressed: () => _saveAndContinue(requireHost: true),
                      child: const Text('Save and continue'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 56,
                    child: TextButton(
                      key: const Key('link-skip'),
                      onPressed: () => _saveAndContinue(requireHost: false),
                      child: const Text('Skip — phone only for now'),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
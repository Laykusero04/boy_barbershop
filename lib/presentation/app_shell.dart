import 'package:flutter/material.dart';

import 'package:boy_barbershop/models/app_user.dart';
import 'package:boy_barbershop/presentation/drawer/app_drawer.dart';
import 'package:boy_barbershop/presentation/navigation/destinations.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.user});

  final AppUser user;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  String _selectedId = 'dashboard';

  @override
  Widget build(BuildContext context) {
    // Only show destinations the user's role is allowed to see.
    final allowed = destinationsForRole(widget.user.role);
    final allowedIds = allowed.map((d) => d.id).toSet();

    // If current selection is no longer allowed, fall back to first allowed.
    if (!allowedIds.contains(_selectedId)) {
      _selectedId = allowed.first.id;
    }

    final destination = destinationById(_selectedId);
    return Scaffold(
      appBar: AppBar(
        title: Text(destination.title),
      ),
      drawer: AppDrawer(
        user: widget.user,
        selectedId: _selectedId,
        onSelect: (id) => setState(() => _selectedId = id),
      ),
      body: destination.builder(
        context,
        widget.user,
        (id) {
          if (allowedIds.contains(id)) {
            setState(() => _selectedId = id);
          }
        },
      ),
    );
  }
}


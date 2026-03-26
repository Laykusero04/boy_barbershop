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
  String _selectedId = appDestinations.first.id;

  @override
  Widget build(BuildContext context) {
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
      body: destination.builder(context, widget.user),
    );
  }
}


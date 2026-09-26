import 'package:flutter/material.dart';

import '../../../../core/l10n/app_strings.dart';
import '../../application/create_group_controller.dart';
import '../../data/models/group_models.dart';

class CreateGroupScreen extends StatefulWidget {
  final CreateGroupController controller;
  final ValueChanged<GroupDetail> onCreated;
  const CreateGroupScreen({
    super.key,
    required this.controller,
    required this.onCreated,
  });
  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final formKey = GlobalKey<FormState>();
  final name = TextEditingController();
  final description = TextEditingController();
  @override
  void dispose() {
    name.dispose();
    description.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!formKey.currentState!.validate()) return;
    final result = await widget.controller.submit(
      CreateGroupRequest(
        name: name.text.trim(),
        description: description.text.trim().isEmpty
            ? null
            : description.text.trim(),
      ),
    );
    if (result != null && mounted) widget.onCreated(result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text(AppStrings.createGroupTitle),
      ),
      body: Form(
        key: formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
          children: [
            const Center(child: Text(AppStrings.createGroupDescription)),
            const SizedBox(height: 24),
            Center(
              child: InkWell(
                onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(AppStrings.groupImageUnavailable),
                  ),
                ),
                child: const CircleAvatar(
                  radius: 64,
                  child: Icon(Icons.add_a_photo, size: 40),
                ),
              ),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: name,
              maxLength: 100,
              decoration: const InputDecoration(
                labelText: AppStrings.groupNameLabel,
              ),
              validator: (v) => v == null || v.trim().isEmpty
                  ? AppStrings.groupNameRequired
                  : null,
            ),
            TextFormField(
              controller: description,
              maxLength: 500,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: AppStrings.groupDescriptionOptional,
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: ValueListenableBuilder<CreateGroupState>(
            valueListenable: widget.controller,
            builder: (context, state, child) => ElevatedButton(
              onPressed: state.submitting ? null : submit,
              child: Text(
                state.submitting
                    ? AppStrings.creatingGroup
                    : AppStrings.createGroup,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

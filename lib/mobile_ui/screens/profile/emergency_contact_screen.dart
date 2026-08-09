import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_colors.dart';
import '../../../services/emergency_contact_service.dart';
import '../../../utils/input_validation.dart';

class EmergencyContactScreen extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback? onSaved;

  const EmergencyContactScreen({
    super.key,
    this.isDarkMode = true,
    this.onSaved,
  });

  @override
  State<EmergencyContactScreen> createState() => _EmergencyContactScreenState();
}

class _EmergencyContactScreenState extends State<EmergencyContactScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = EmergencyContactService();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _customRelationshipController = TextEditingController();

  static const List<String> _relationshipOptions = [
    'Parent',
    'Spouse',
    'Sibling',
    'Child',
    'Relative',
    'Partner',
    'Friend',
    'Co-worker',
    'Other',
  ];

  String _selectedRelationship = 'Parent';
  bool _isLoading = true;
  bool _isSaving = false;
  String? _contactId;

  @override
  void initState() {
    super.initState();
    _loadContact();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _customRelationshipController.dispose();
    super.dispose();
  }

  Future<void> _loadContact() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final contact = await _service.getDefaultContact();
      if (contact != null) {
        _contactId = contact['id']?.toString();
        _nameController.text = contact['full_name']?.toString() ?? '';
        _phoneController.text = contact['phone_number']?.toString() ?? '';

        final rawRel = contact['relationship']?.toString().trim() ?? '';
        if (rawRel.isNotEmpty) {
          final matched = _relationshipOptions.firstWhere(
            (opt) =>
                opt.toLowerCase() == rawRel.toLowerCase() ||
                (opt.toLowerCase() == 'sibling' &&
                    rawRel.toLowerCase() == 'siblings') ||
                (opt.toLowerCase() == 'parent' &&
                    (rawRel.toLowerCase() == 'father' ||
                        rawRel.toLowerCase() == 'mother')),
            orElse: () => '',
          );
          if (matched.isNotEmpty) {
            _selectedRelationship = matched;
          } else {
            _selectedRelationship = 'Other';
            _customRelationshipController.text = rawRel;
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load emergency contact: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveContact() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final relationship = _selectedRelationship == 'Other'
        ? _customRelationshipController.text.trim()
        : _selectedRelationship;

    if (name.isEmpty || phone.isEmpty || relationship.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please complete all emergency contact fields.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final saved = await _service.saveContact(
        contactId: _contactId,
        fullName: name,
        phoneNumber: phone,
        relationship: relationship,
        isDefault: true,
      );
      _contactId = saved['id']?.toString();
      widget.onSaved?.call();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Emergency contact saved.'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save emergency contact: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: AppColors.darkBg,
        elevation: 0,
        title: const Text('Emergency Contact'),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.darkBgSecondary,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.borderColor),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.health_and_safety_outlined,
                                color: AppColors.primary,
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Safety contact on file',
                                  style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 10),
                          Text(
                            'PSDC can use this contact if a renter or driver needs urgent help during an accident or safety incident.',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildField(
                      label: 'Full name',
                      controller: _nameController,
                      icon: Icons.person_outline,
                      textCapitalization: TextCapitalization.words,
                      validator: (value) =>
                          validatePersonName(value, fieldName: 'Contact name'),
                    ),
                    const SizedBox(height: 16),
                    _buildField(
                      label: 'Phone number',
                      controller: _phoneController,
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      inputFormatters: philippineMobileInputFormatters,
                      validator: validatePhilippineMobile,
                    ),
                    const SizedBox(height: 16),
                    _buildRelationshipDropdown(),
                    if (_selectedRelationship == 'Other') ...[
                      const SizedBox(height: 16),
                      _buildField(
                        label: 'Specify Relationship',
                        controller: _customRelationshipController,
                        icon: Icons.edit_note_outlined,
                        hint: 'e.g. Guardian, Neighbor, Cousin',
                        textCapitalization: TextCapitalization.words,
                        validator: (value) => validateRequiredText(
                          value,
                          fieldName: 'Relationship',
                          minLength: 2,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.3),
                        ),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            color: AppColors.primary,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'This contact will be saved as your default emergency contact.',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: SizedBox(
            height: 54,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _saveContact,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.black,
                      ),
                    )
                  : const Text(
                      'Save Emergency Contact',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRelationshipDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Relationship',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _relationshipOptions.contains(_selectedRelationship)
              ? _selectedRelationship
              : 'Other',
          dropdownColor: AppColors.darkBgSecondary,
          style: const TextStyle(color: AppColors.textPrimary),
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: AppColors.primary,
          ),
          decoration: InputDecoration(
            prefixIcon: const Icon(
              Icons.family_restroom_outlined,
              color: AppColors.primary,
            ),
            filled: true,
            fillColor: AppColors.darkBgSecondary,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.primary),
            ),
          ),
          items: _relationshipOptions.map((opt) {
            return DropdownMenuItem<String>(
              value: opt,
              child: Text(
                opt,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                ),
              ),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) {
              setState(() {
                _selectedRelationship = val;
              });
            }
          },
        ),
      ],
    );
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? hint,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          validator: validator,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          textCapitalization: textCapitalization,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: AppColors.textTertiary),
            prefixIcon: Icon(icon, color: AppColors.primary),
            filled: true,
            fillColor: AppColors.darkBgSecondary,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.primary),
            ),
          ),
        ),
      ],
    );
  }
}

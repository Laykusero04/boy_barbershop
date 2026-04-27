import 'package:flutter/material.dart';

import 'package:boy_barbershop/models/barber_shift.dart';

/// Result of the End Duty dialog.
sealed class EndDutyResult {
  const EndDutyResult();
}

class EndDutyClose extends EndDutyResult {
  const EndDutyClose(this.classification);
  final DayClassification classification;
}

class EndDutyDiscard extends EndDutyResult {
  const EndDutyDiscard();
}

enum _DutyChoice { fullDay, halfDay, mistake }

/// Asks the cashier/admin how to end a barber's duty.
///
/// Three options:
///  - Full day: charge full daily rate
///  - Half day: charge configured half-day percentage
///  - Opened by mistake: delete the shift entirely (no salary charge)
class EndDutyDialog extends StatefulWidget {
  const EndDutyDialog({super.key, required this.barberName});

  final String barberName;

  @override
  State<EndDutyDialog> createState() => _EndDutyDialogState();
}

class _EndDutyDialogState extends State<EndDutyDialog> {
  _DutyChoice _value = _DutyChoice.fullDay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMistake = _value == _DutyChoice.mistake;
    return AlertDialog(
      title: const Text('End duty'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('How should ${widget.barberName}’s duty be handled?'),
          const SizedBox(height: 12),
          RadioGroup<_DutyChoice>(
            groupValue: _value,
            onChanged: (v) {
              if (v != null) setState(() => _value = v);
            },
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile<_DutyChoice>(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text('Full day'),
                  subtitle: Text('Charge full daily rate'),
                  value: _DutyChoice.fullDay,
                ),
                RadioListTile<_DutyChoice>(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text('Half day'),
                  subtitle: Text('Charge half-day percentage from Settings'),
                  value: _DutyChoice.halfDay,
                ),
                RadioListTile<_DutyChoice>(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text('Opened by mistake'),
                  subtitle:
                      Text('Discard the duty entry — no salary will be charged'),
                  value: _DutyChoice.mistake,
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            EndDutyResult result;
            switch (_value) {
              case _DutyChoice.fullDay:
                result = const EndDutyClose(DayClassification.full);
              case _DutyChoice.halfDay:
                result = const EndDutyClose(DayClassification.half);
              case _DutyChoice.mistake:
                result = const EndDutyDiscard();
            }
            Navigator.of(context).pop(result);
          },
          style: isMistake
              ? FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.error,
                )
              : null,
          child: Text(isMistake ? 'Discard duty' : 'End duty'),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:wiredash/src/common/theme/wiredash_theme.dart';
import 'package:wiredash/src/common/translation/wiredash_localizations.dart';
import 'package:wiredash/src/common/utils/email_validator.dart';
import 'package:wiredash/src/common/widgets/wiredash_icons.dart';
import 'package:wiredash/src/wiredash_provider.dart';

enum InputComponentType { feedback }

class InputComponent extends StatefulWidget {
  final InputComponentType type;
  final GlobalKey<FormState> formKey;
  final FocusNode focusNode;
  final String? prefill;
  final bool autofocus;

  const InputComponent({
    Key? key,
    required this.type,
    required this.formKey,
    required this.focusNode,
    this.prefill,
    this.autofocus = false,
  }) : super(key: key);

  @override
  _InputComponentState createState() => _InputComponentState();
}

class _InputComponentState extends State<InputComponent> {
  late TextEditingController _textEditingController;

  static const _maxInputLength = 2048;
  static const _lengthWarningThreshold = 50;

  @override
  void initState() {
    super.initState();
    _textEditingController = TextEditingController(text: widget.prefill);
    SchedulerBinding.instance!.addPostFrameCallback((timeStamp) {
      if (widget.autofocus) {
        widget.focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _textEditingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final interactiveTextSelectionSupported =
        Localizations.of<MaterialLocalizations>(
              context,
              MaterialLocalizations,
            ) !=
            null;

    final wiredashTheme = WiredashTheme.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Form(
        key: widget.formKey,
        child: TextFormField(
          key: const ValueKey('wiredash.sdk.text_field'),
          controller: _textEditingController,
          focusNode: widget.focusNode,
          style: wiredashTheme.inputTextStyle,
          cursorColor: wiredashTheme.primaryColor,
          validator: _validateInput,
          onSaved: _handleInput,
          enableInteractiveSelection: interactiveTextSelectionSupported,
          decoration: InputDecoration(
            errorBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: wiredashTheme.errorColor, width: 2),
            ),
            focusedErrorBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: wiredashTheme.errorColor, width: 2),
            ),
            enabledBorder: UnderlineInputBorder(
              borderSide:
                  BorderSide(color: wiredashTheme.dividerColor, width: 2),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide:
                  BorderSide(color: wiredashTheme.primaryColor, width: 2),
            ),
            icon: Icon(
              _getIcon(),
              color: wiredashTheme.dividerColor,
              size: 20,
            ),
            hintText: _getHintText(),
            hintStyle: wiredashTheme.inputHintStyle,
            errorStyle: wiredashTheme.inputErrorStyle,
            errorMaxLines: 2,
          ),
          maxLength: _maxInputLength,
          maxLengthEnforcement: MaxLengthEnforcement.none,
          buildCounter: _getCounterText,
          textCapitalization: _getTextCapitalization(),
          keyboardAppearance: WiredashTheme.of(context)!.brightness,
          keyboardType: _getKeyboardType(),
        ),
      ),
    );
  }

  TextCapitalization _getTextCapitalization() {
    return TextCapitalization.sentences;
  }

  TextInputType _getKeyboardType() {
    return TextInputType.text;
  }

  IconData _getIcon() {
    return WiredashIcons.edit;
  }

  String _getHintText() {
    return WiredashLocalizations.of(context)!.inputHintFeedback;
  }

  Widget? _getCounterText(
    /// The build context for the TextField.
    BuildContext context, {

    /// The length of the string currently in the input.
    required int currentLength,

    /// The maximum string length that can be entered into the TextField.
    required int? maxLength,

    /// Whether or not the TextField is currently focused.  Mainly provided for
    /// the [liveRegion] parameter in the [Semantics] widget for accessibility.
    required bool isFocused,
  }) {
    final theme = WiredashTheme.of(context)!;
    final max = maxLength ?? _maxInputLength;
    switch (widget.type) {
      case InputComponentType.feedback:
        final difference = max - currentLength;
        return difference <= _lengthWarningThreshold
            ? Text(
                '$currentLength / $_maxInputLength',
                style: currentLength > max
                    ? theme.inputHintStyle.copyWith(color: theme.errorColor)
                    : theme.inputHintStyle,
              )
            : null;
      default:
        return null;
    }
  }

  String? _validateInput(String? input) {
    final text = input ?? "";
    if (text.trim().isEmpty) {
      return WiredashLocalizations.of(context)!.validationHintFeedbackEmpty;
    } else if (text.characters.length > _maxInputLength) {
      return WiredashLocalizations.of(context)!.validationHintFeedbackLength;
    }
    return null;
  }

  void _handleInput(String? input) =>
      context.feedbackModel!.feedbackMessage = input;
}

@visibleForTesting
EmailValidator debugEmailValidator = const EmailValidator();

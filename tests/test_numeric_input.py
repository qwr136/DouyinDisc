"""Numeric-entry regression wiring; runtime behavior is exercised by UIKit host."""
from pathlib import Path
import re
import unittest
ROOT=Path(__file__).resolve().parent.parent

class NumericInputTests(unittest.TestCase):
    def test_all_three_values_are_editable_number_pad_fields(self):
        panel=(ROOT/'Sources/DouyinDiscNavigation.m').read_text()
        for part in ('angleValue','cornerValue','rotationSpeedValue'):
            self.assertIn(f'self.douyindisc_{part}=[UITextField new]',panel)
            self.assertNotIn(f'self.douyindisc_{part}=[UILabel new]',panel)
        for token in ('field.keyboardType=UIKeyboardTypeNumberPad',
                      'action:@selector(douyindisc_editingAppearanceInput:) forControlEvents:UIControlEventEditingDidBegin',
                      'action:@selector(douyindisc_commitAppearanceInput:) forControlEvents:UIControlEventEditingDidEnd',
                      'field.inputAccessoryView=toolbar',
                      '- (void)douyindisc_inputAccessoryDone { [self endEditing:YES]; }'):
            self.assertIn(token,panel)

    def test_integer_parser_clamps_without_overflow_or_invalid_writes(self):
        panel=(ROOT/'Sources/DouyinDiscNavigation.m').read_text()
        block=panel.split('- (void)douyindisc_commitAppearanceInput:(UITextField *)field {',1)[1].split('\n}',1)[0]
        for token in ('maximum=angle?359:(speed?300:50)',"digit<'0'||digit>'9'",'MIN(maximum,value*10+',
                      'if(!valid||value==previous)return;', 'self.douyindisc_rotationSpeed=value/100.0'):
            self.assertIn(token,block)
        self.assertNotIn('doubleValue',block)
        for part in ('changeAngle','changeCorner','changeRotationSpeed'):
            self.assertIn(f'- (void)douyindisc_{part}:(NSInteger)delta {{[self endEditing:YES];',panel)
        self.assertIn('[self.view endEditing:YES];',panel)

    def test_runtime_input_and_layout_checks_are_really_called(self):
        panel=(ROOT/'Sources/DouyinDiscNavigation.m').read_text()
        host=(ROOT/'tests/ui/DouyinDiscNativeHost.m').read_text()
        helper=(ROOT/'tests/ui/DouyinDiscNumericInputCases.inc').read_text()
        self.assertIn('#include "../tests/ui/DouyinDiscNumericInputCases.inc"',panel)
        self.assertIn('douyindisc_uiTestNumericInput(self.window)',host)
        self.assertIn('douyindisc_uiTestKeyboardVisible(self.window',host)
        self.assertIn('UIKeyboardDidShowNotification',helper)
        self.assertIn('CGRectGetHeight(intersection)>100',helper)
        self.assertIn('DD_CHECK_NS([numeric[key] boolValue],label)',host)
        for token in ('[window hitTest:point withEvent:nil]','becomeFirstResponder','isFirstResponder',
                      'UIControlEventEditingDidBegin','UIControlEventEditingDidEnd',
                      'coldStorePersistence','saveFailureRollback','reopenPersistence'):
            self.assertIn(token,helper)
        self.assertIn('all 256 control centers hit',host)
        for part in ('angle','corner'):
            self.assertIn(f'douyindisc_{part}Value.centerYAnchor constraintEqualToAnchor:self.douyindisc_{part}Minus.centerYAnchor',panel)

if __name__=='__main__':unittest.main()

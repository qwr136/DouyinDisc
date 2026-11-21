#!/usr/bin/env python3
"""源码测试入口；拒绝空套件/全跳过，按测试用例而非失败断言统计。"""
import argparse
import sys
import unittest
from datetime import datetime, timezone
from pathlib import Path

TESTS = Path(__file__).resolve().parent
REPORT = TESTS / 'report.txt'


class CaseResult(unittest.TextTestResult):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.passed_cases = set()
        self.failed_cases = set()

    def addSuccess(self, test):
        super().addSuccess(test)
        self.passed_cases.add(test.id())

    def addFailure(self, test, err):
        super().addFailure(test, err)
        self.failed_cases.add(test.id())

    def addError(self, test, err):
        super().addError(test, err)
        self.failed_cases.add(test.id())

    def addUnexpectedSuccess(self, test):
        super().addUnexpectedSuccess(test)
        self.failed_cases.add(test.id())

    def addSubTest(self, test, subtest, err):
        super().addSubTest(test, subtest, err)
        if err is not None:
            self.failed_cases.add(test.id())


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('-v', action='store_true')
    parser.add_argument('--pattern', default='test_*.py', help='explicit subset; never reported as full coverage')
    args = parser.parse_args(argv)
    if '/' in args.pattern or '\\' in args.pattern or not args.pattern.endswith('.py'):
        parser.error('pattern must select test file names within tests/')
    suite = unittest.TestLoader().discover(str(TESTS), pattern=args.pattern, top_level_dir=str(TESTS))
    with REPORT.open('w', encoding='utf-8') as stream:
        stream.write('源码测试报告\n时间: '+datetime.now(timezone.utc).strftime('%Y-%m-%d %H:%M:%SZ')+'\n')
        stream.write('说明: 本报告只代表源码层测试，不代表可编译或真机可用。\n')
        stream.write('范围: '+args.pattern+('（局部预检，非全量）' if args.pattern != 'test_*.py' else '（完整发现）')+'\n')
        stream.write('='*60+'\n')
        result = unittest.TextTestRunner(stream=stream, verbosity=2 if args.v else 1,
                                         resultclass=CaseResult).run(suite)
        total = result.testsRun
        passed, failed = len(result.passed_cases), len(result.failed_cases)
        skipped, expected = len(result.skipped), len(result.expectedFailures)
        # unittest records several failing subtests as several events, but only
        # one parent test case ran. Never subtract event count from case count.
        events = len(result.failures)+len(result.errors)+len(result.unexpectedSuccesses)
        summary = (f'结果: 总计 {total}, 通过 {passed}, 失败 {failed}, '
                   f'跳过 {skipped}, 预期失败 {expected}, 失败事件 {events}')
        stream.write('\n'+summary+'\n')
        valid = total > 0 and passed > 0 and result.wasSuccessful()
        if not valid and (total == 0 or passed == 0):
            stream.write('ERROR: 测试为空或没有任何成功执行的测试，不得作为有效验收。\n')
    print(summary)
    print('报告: '+str(REPORT))
    return 0 if valid else 1


if __name__ == '__main__':
    sys.exit(main())

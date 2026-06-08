import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/features/auth/domain/auth_models.dart';
import 'package:orbixhub_front/features/team/domain/team_models.dart';
import 'package:orbixhub_front/features/team/presentation/team_guards.dart';

Me _me({required String userId, required String role}) => Me(
      user: User(id: userId, email: 'me@b.c', fullName: 'Me'),
      role: role,
    );

Employee _emp({
  required String userId,
  required String role,
  required String status,
}) =>
    Employee(
      membershipId: 'm-$userId',
      userId: userId,
      fullName: 'Emp $userId',
      email: '$userId@b.c',
      role: role,
      status: status,
    );

void main() {
  group('teamActions', () {
    test('self cannot change own role or deactivate self', () {
      final me = _me(userId: 'u1', role: 'manager');
      final target = _emp(userId: 'u1', role: 'manager', status: 'active');
      final actions = teamActions(me, target, [target]);

      expect(actions.canChangeRole, isFalse);
      expect(actions.canDeactivate, isFalse);
    });

    test('last active owner cannot be deactivated', () {
      final me = _me(userId: 'admin', role: 'owner');
      final owner = _emp(userId: 'o1', role: 'owner', status: 'active');
      final actions = teamActions(me, owner, [owner]);

      expect(actions.canDeactivate, isFalse);
    });

    test('owner can be deactivated when another active owner exists', () {
      final me = _me(userId: 'admin', role: 'owner');
      final owner1 = _emp(userId: 'o1', role: 'owner', status: 'active');
      final owner2 = _emp(userId: 'o2', role: 'owner', status: 'active');
      final actions = teamActions(me, owner1, [owner1, owner2]);

      expect(actions.canDeactivate, isTrue);
    });

    test('canAssignOwner is true only when the caller is an owner', () {
      final target = _emp(userId: 'u2', role: 'manager', status: 'active');

      final asOwner = teamActions(
        _me(userId: 'admin', role: 'owner'),
        target,
        [target],
      );
      final asManager = teamActions(
        _me(userId: 'admin', role: 'manager'),
        target,
        [target],
      );

      expect(asOwner.canAssignOwner, isTrue);
      expect(asManager.canAssignOwner, isFalse);
    });
  });
}

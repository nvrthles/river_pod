import 'package:flutter/material.dart' hide Listener;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'utils.dart';

void main() {
  group('WidgetRef.listen', () {
    testWidgets('can downcast the value', (tester) async {
      final dep = StateProvider((ref) => 0);
      final provider = Provider((ref) => ref.watch(dep).state);

      final container = createContainer();
      final listener = Listener<num>();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: Consumer(
            builder: (context, ref, _) {
              ref.listen<num>(provider, listener);
              return Container();
            },
          ),
        ),
      );

      verifyZeroInteractions(listener);

      container.read(dep).state++;
      await tester.pump();

      verifyOnly(listener, listener(1));
    });

    testWidgets('works with providers that returns null', (tester) async {
      final nullProvider = Provider((ref) => null);

      // should compile
      Consumer(
        builder: (context, ref, _) {
          ref.listen<Object?>(nullProvider, (_) {});
          return Container();
        },
      );
    });

    testWidgets('can mark parents as dirty during onChange', (tester) async {
      final container = createContainer();
      final provider = StateProvider((ref) => 0);
      final onChange = Listener<int>();

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return UncontrolledProviderScope(
              container: container,
              child: Consumer(
                builder: (context, ref, _) {
                  ref.listen<StateController<int>>(
                      provider, (v) => setState(() {}));
                  return Container();
                },
              ),
            );
          },
        ),
      );

      verifyZeroInteractions(onChange);

      // This would fail if the setState was not allowed
      container.read(provider).state++;
    });

    testWidgets('calls onChange synchronously if possible', (tester) async {
      final provider = StateProvider((ref) => 0);
      final onChange = Listener<int>();
      final container = createContainer();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: Consumer(
            builder: (context, ref, _) {
              ref.listen<StateController<int>>(
                provider,
                (v) => onChange(v.state),
              );
              return Container();
            },
          ),
        ),
      );
      verifyZeroInteractions(onChange);

      container.read(provider).state++;
      container.read(provider).state++;
      container.read(provider).state++;

      verifyInOrder([
        onChange(1),
        onChange(2),
        onChange(3),
      ]);
      verifyNoMoreInteractions(onChange);
    });

    testWidgets('calls onChange asynchronously if the change is indirect',
        (tester) async {
      final provider = StateProvider((ref) => 0);
      final isEven = Provider((ref) => ref.watch(provider).state.isEven);
      final onChange = Listener<bool>();
      final container = createContainer();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: Consumer(
            builder: (context, ref, _) {
              ref.listen<bool>(isEven, onChange);
              return Container();
            },
          ),
        ),
      );
      verifyZeroInteractions(onChange);

      container.read(provider).state++;
      container.read(provider).state++;
      container.read(provider).state++;

      verifyZeroInteractions(onChange);

      await tester.pump();

      verifyOnly(onChange, onChange(false));
    });

    testWidgets('closes the subscription on dispose', (tester) async {
      final provider = StateProvider((ref) => 0);
      final onChange = Listener<int>();
      final container = createContainer();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: Consumer(
            builder: (context, ref, _) {
              ref.listen<StateController<int>>(
                  provider, (v) => onChange(v.state));
              return Container();
            },
          ),
        ),
      );

      expect(container.readProviderElement(provider).hasListeners, true);

      await tester.pumpWidget(Container());

      expect(container.readProviderElement(provider).hasListeners, false);
    });

    testWidgets('closes the subscription on provider change', (tester) async {
      final provider = StateProvider.family<int, int>((ref, _) => 0);
      final container = createContainer();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: Consumer(
            builder: (context, ref, _) {
              ref.listen<StateController<int>>(provider(0), (v) {});
              return Container();
            },
          ),
        ),
      );

      expect(container.readProviderElement(provider(0)).hasListeners, true);
      expect(container.readProviderElement(provider(1)).hasListeners, false);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: Consumer(
            builder: (context, ref, _) {
              ref.listen<StateController<int>>(provider(1), (v) {});
              return Container();
            },
          ),
        ),
      );

      expect(container.readProviderElement(provider(0)).hasListeners, false);
      expect(container.readProviderElement(provider(1)).hasListeners, true);
    });

    testWidgets('listen to the new provider on provider change',
        (tester) async {
      final provider = StateProvider.family<int, int>((ref, _) => 0);
      final container = createContainer();
      final onChange = Listener<int>();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: Consumer(
            builder: (context, ref, _) {
              ref.listen<StateController<int>>(
                provider(0),
                (v) => onChange(v.state),
              );
              return Container();
            },
          ),
        ),
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: Consumer(
            builder: (context, ref, _) {
              ref.listen<StateController<int>>(
                provider(1),
                (v) => onChange(v.state),
              );
              return Container();
            },
          ),
        ),
      );

      verifyZeroInteractions(onChange);

      container.read(provider(0)).state++;
      container.read(provider(1)).state = 42;

      await Future<void>.value();

      verifyOnly(onChange, onChange(42));
    });

    testWidgets('supports Changing the ProviderContainer', (tester) async {
      final provider = Provider((ref) => 0);
      final onChange = Listener<int>();
      final container = createContainer(overrides: [
        provider.overrideWithValue(0),
      ]);
      final container2 = createContainer(overrides: [
        provider.overrideWithValue(0),
      ]);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: Consumer(
            builder: (context, ref, _) {
              ref.listen<int>(provider, onChange);
              return Container();
            },
          ),
        ),
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container2,
          child: Consumer(
            builder: (context, ref, _) {
              ref.listen<int>(provider, onChange);
              return Container();
            },
          ),
        ),
      );

      container.updateOverrides([
        provider.overrideWithValue(21),
      ]);
      container2.updateOverrides([
        provider.overrideWithValue(42),
      ]);

      await Future<void>.value();

      verifyOnly(onChange, onChange(42));
    });

    testWidgets('supports overriding Providers', (tester) async {
      final provider = Provider((ref) => 0);
      final onChange = Listener<int>();
      final container = createContainer(overrides: [
        provider.overrideWithValue(42),
      ]);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: Consumer(
            builder: (context, ref, _) {
              ref.listen<int>(provider, onChange);
              return Container();
            },
          ),
        ),
      );

      container.updateOverrides([
        provider.overrideWithValue(21),
      ]);

      await Future<void>.value();

      verifyOnly(onChange, onChange(21));
    });
  });
}

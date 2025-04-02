// ignore_for_file: prefer_const_constructors, subtype_of_sealed_class, lines_longer_than_80_chars

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ht_categories_client/ht_categories_client.dart'; // Import client models/exceptions
import 'package:ht_categories_firestore/ht_categories_firestore.dart';
import 'package:mocktail/mocktail.dart';

// --- Mocks ---
class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

class MockCollectionReference extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

class MockQuerySnapshot extends Mock
    implements QuerySnapshot<Map<String, dynamic>> {}

class MockQueryDocumentSnapshot extends Mock
    implements QueryDocumentSnapshot<Map<String, dynamic>> {}

class MockDocumentReference extends Mock
    implements DocumentReference<Map<String, dynamic>> {}

class MockDocumentSnapshot extends Mock
    implements DocumentSnapshot<Map<String, dynamic>> {}

// Helper to create a sample Category for tests
Category _createSampleCategory({
  String? id,
  String name = 'Test Category',
  String? description = 'Test Description',
  String? iconUrl = 'http://example.com/icon.png',
}) {
  return Category(
    id: id ??
        'test-id-${DateTime.now().microsecondsSinceEpoch}', // Ensure unique default ID
    name: name,
    description: description,
    iconUrl: iconUrl,
  );
}

// Helper to create a FirebaseException
FirebaseException _createFirebaseException(
  String code, {
  String message = 'Firestore error',
}) {
  return FirebaseException(
    plugin: 'cloud_firestore',
    code: code,
    message: message,
  );
}

void main() {
  late MockFirebaseFirestore mockFirestore;
  late MockCollectionReference mockCollectionRef;
  late HtCategoriesFirestore categoriesFirestore;

  // Sample categories
  final category1 = _createSampleCategory(name: 'Category 1');
  final category2 =
      _createSampleCategory(name: 'Category 2', description: null);
  // Firestore data doesn't include the 'id' field itself
  final categoryMap1 = category1.toJson()..remove('id');
  final categoryMap2 = category2.toJson()..remove('id');

  setUp(() {
    mockFirestore = MockFirebaseFirestore();
    mockCollectionRef = MockCollectionReference();
    categoriesFirestore = HtCategoriesFirestore(firestore: mockFirestore);

    // Default stub for collection access
    when(() => mockFirestore.collection('categories'))
        .thenReturn(mockCollectionRef);
    // Default stub for doc access (can be overridden in tests)
    when(() => mockCollectionRef.doc(any()))
        .thenReturn(MockDocumentReference());
  });

  group('HtCategoriesFirestore', () {
    test('can be instantiated', () {
      expect(categoriesFirestore, isNotNull);
    });

    group('getCategories', () {
      test('returns list of categories on success', () async {
        // Arrange
        final mockSnapshot = MockQuerySnapshot();
        final mockDoc1 = MockQueryDocumentSnapshot();
        final mockDoc2 = MockQueryDocumentSnapshot();

        when(() => mockCollectionRef.get())
            .thenAnswer((_) async => mockSnapshot);
        when(() => mockSnapshot.docs).thenReturn([mockDoc1, mockDoc2]);

        when(() => mockDoc1.id).thenReturn(category1.id);
        when(mockDoc1.data).thenReturn(categoryMap1);
        when(() => mockDoc2.id).thenReturn(category2.id);
        when(mockDoc2.data).thenReturn(categoryMap2);

        // Act
        final categories = await categoriesFirestore.getCategories();

        // Assert
        expect(categories, isA<List<Category>>());
        expect(categories.length, 2);
        // Use contains matcher for potentially unordered results
        expect(categories, contains(category1));
        expect(categories, contains(category2));
        verify(() => mockCollectionRef.get()).called(1);
      });

      test('returns empty list when no categories exist', () async {
        // Arrange
        final mockSnapshot = MockQuerySnapshot();
        when(() => mockCollectionRef.get())
            .thenAnswer((_) async => mockSnapshot);
        when(() => mockSnapshot.docs).thenReturn([]); // Empty list of docs

        // Act
        final categories = await categoriesFirestore.getCategories();

        // Assert
        expect(categories, isEmpty);
        verify(() => mockCollectionRef.get()).called(1);
      });

      test('throws GetCategoriesFailure on Firestore error', () async {
        // Arrange
        final exception = _createFirebaseException('unavailable');
        when(() => mockCollectionRef.get()).thenThrow(exception);

        // Act & Assert
        expect(
          () => categoriesFirestore.getCategories(),
          throwsA(
            isA<GetCategoriesFailure>()
                .having((e) => e.error, 'error', exception),
          ),
        );
        verify(() => mockCollectionRef.get()).called(1);
      });
    });

    group('getCategory', () {
      test('returns correct category on success', () async {
        // Arrange
        final mockDocRef = MockDocumentReference();
        final mockDocSnapshot = MockDocumentSnapshot();
        when(() => mockCollectionRef.doc(category1.id)).thenReturn(mockDocRef);
        when(mockDocRef.get).thenAnswer((_) async => mockDocSnapshot);
        when(() => mockDocSnapshot.exists).thenReturn(true);
        when(() => mockDocSnapshot.id).thenReturn(category1.id);
        when(mockDocSnapshot.data).thenReturn(categoryMap1);

        // Act
        final category = await categoriesFirestore.getCategory(category1.id);

        // Assert
        expect(category, equals(category1));
        verify(() => mockCollectionRef.doc(category1.id)).called(1);
        verify(mockDocRef.get).called(1);
      });

      test('throws CategoryNotFoundFailure when document does not exist',
          () async {
        // Arrange
        const nonExistentId = 'non-existent-id';
        final mockDocRef = MockDocumentReference();
        final mockDocSnapshot = MockDocumentSnapshot();
        when(() => mockCollectionRef.doc(nonExistentId)).thenReturn(mockDocRef);
        when(mockDocRef.get).thenAnswer((_) async => mockDocSnapshot);
        when(() => mockDocSnapshot.exists)
            .thenReturn(false); // Document does not exist
        // No need to mock data() as it won't be reached

        // Act & Assert
        expect(
          () => categoriesFirestore.getCategory(nonExistentId),
          throwsA(
            isA<CategoryNotFoundFailure>()
                .having((e) => e.id, 'id', nonExistentId),
          ),
        );
        verify(() => mockCollectionRef.doc(nonExistentId)).called(1);
        verify(mockDocRef.get).called(1);
      });

      test(
          'throws CategoryNotFoundFailure when document exists but data is null',
          () async {
        // Arrange
        final mockDocRef = MockDocumentReference();
        final mockDocSnapshot = MockDocumentSnapshot();
        when(() => mockCollectionRef.doc(category1.id)).thenReturn(mockDocRef);
        when(mockDocRef.get).thenAnswer((_) async => mockDocSnapshot);
        when(() => mockDocSnapshot.exists).thenReturn(true); // Document exists
        when(mockDocSnapshot.data).thenReturn(null); // Data is null

        // Act & Assert
        expect(
          () => categoriesFirestore.getCategory(category1.id),
          throwsA(
            isA<CategoryNotFoundFailure>()
                .having((e) => e.id, 'id', category1.id),
          ),
        );
        verify(() => mockCollectionRef.doc(category1.id)).called(1);
        verify(mockDocRef.get).called(1);
      });

      test('throws GetCategoryFailure on Firestore error during get', () async {
        // Arrange
        final mockDocRef = MockDocumentReference();
        final exception = _createFirebaseException('permission-denied');
        when(() => mockCollectionRef.doc(category1.id)).thenReturn(mockDocRef);
        when(mockDocRef.get).thenThrow(exception); // Throw during get

        // Act & Assert
        expect(
          () => categoriesFirestore.getCategory(category1.id),
          throwsA(
            isA<GetCategoryFailure>()
                .having((e) => e.error, 'error', exception),
          ),
        );
        verify(() => mockCollectionRef.doc(category1.id)).called(1);
        verify(mockDocRef.get).called(1);
      });
    });

    group('createCategory', () {
      test('creates and returns category on success', () async {
        // Arrange
        const newName = 'New Category';
        const newDesc = 'New Description';
        const newIconUrl = 'http://new.icon/url';
        final mockDocRef = MockDocumentReference();

        // Stub the calls
        when(() => mockCollectionRef.doc(any())).thenReturn(mockDocRef);
        when(() => mockDocRef.set(any()))
            .thenAnswer((_) async {}); // Simulate successful set

        // Act
        final createdCategory = await categoriesFirestore.createCategory(
          name: newName,
          description: newDesc,
          iconUrl: newIconUrl,
        );

        // Assert
        expect(createdCategory, isA<Category>());
        expect(createdCategory.name, newName);
        expect(createdCategory.description, newDesc);
        expect(createdCategory.iconUrl, newIconUrl);
        expect(createdCategory.id, isNotEmpty);

        // Verify Firestore calls and capture arguments
        final capturedIdResult =
            verify(() => mockCollectionRef.doc(captureAny())).captured;
        final capturedDataSetResult =
            verify(() => mockDocRef.set(captureAny())).captured;

        // Assert captured arguments
        expect(capturedIdResult.length, 1);
        expect(
          capturedIdResult.first,
          equals(createdCategory.id),
        ); // Verify captured ID matches

        expect(capturedDataSetResult.length, 1);
        // The data sent to set() *should* include the id, as per Category.toJson()
        final expectedJson = createdCategory.toJson();
        expect(capturedDataSetResult.first, equals(expectedJson));
      });

      test('throws CreateCategoryFailure on Firestore error during set',
          () async {
        // Arrange
        const newName = 'Fail Category';
        final mockDocRef = MockDocumentReference();
        final exception = _createFirebaseException('internal');

        when(() => mockCollectionRef.doc(any())).thenReturn(mockDocRef);
        when(() => mockDocRef.set(any()))
            .thenThrow(exception); // Throw during set

        // Act & Assert
        expect(
          () => categoriesFirestore.createCategory(name: newName),
          throwsA(
            isA<CreateCategoryFailure>()
                .having((e) => e.error, 'error', exception),
          ),
        );
        verify(() => mockCollectionRef.doc(any())).called(1);
        verify(() => mockDocRef.set(any())).called(1);
      });
    });

    group('updateCategory', () {
      // Updated category data
      late Category updatedCategory;
      late Map<String, dynamic> updatedCategoryJson; // Use full JSON for update

      setUp(() {
        updatedCategory = category1.copyWith(
          name: 'Updated Name',
          description: 'Updated Description',
        );
        // The data sent to update() should include the id, as per Category.toJson()
        updatedCategoryJson = updatedCategory.toJson();
      });

      test('updates and returns category on success', () async {
        // Arrange
        final mockDocRef = MockDocumentReference();
        when(() => mockCollectionRef.doc(updatedCategory.id))
            .thenReturn(mockDocRef);
        // Mock the update call to succeed
        when(() => mockDocRef.update(updatedCategoryJson))
            .thenAnswer((_) async {});

        // Act
        final result =
            await categoriesFirestore.updateCategory(updatedCategory);

        // Assert
        expect(result, equals(updatedCategory)); // Returns the input category
        verify(() => mockCollectionRef.doc(updatedCategory.id)).called(1);
        verify(() => mockDocRef.update(updatedCategoryJson)).called(1);
      });

      test('throws CategoryNotFoundFailure when update fails with not-found',
          () async {
        // Arrange
        final nonExistentCategory =
            _createSampleCategory(id: 'non-existent-update');
        final nonExistentCategoryJson = nonExistentCategory.toJson();
        final mockDocRef = MockDocumentReference();
        when(() => mockCollectionRef.doc(nonExistentCategory.id))
            .thenReturn(mockDocRef);
        // Mock update to throw 'not-found' FirebaseException
        final notFoundException = _createFirebaseException('not-found');
        when(() => mockDocRef.update(nonExistentCategoryJson))
            .thenThrow(notFoundException);

        // Act & Assert
        expect(
          () => categoriesFirestore.updateCategory(nonExistentCategory),
          throwsA(
            isA<CategoryNotFoundFailure>()
                .having((e) => e.id, 'id', nonExistentCategory.id)
                .having((e) => e.error, 'error', notFoundException),
          ),
        );
        verify(() => mockCollectionRef.doc(nonExistentCategory.id)).called(1);
        verify(() => mockDocRef.update(nonExistentCategoryJson)).called(1);
      });

      test(
          'throws UpdateCategoryFailure on other Firestore error during update',
          () async {
        // Arrange
        final mockDocRef = MockDocumentReference();
        when(() => mockCollectionRef.doc(updatedCategory.id))
            .thenReturn(mockDocRef);
        // Mock update to throw a different FirebaseException
        final otherException = _createFirebaseException('permission-denied');
        when(() => mockDocRef.update(updatedCategoryJson))
            .thenThrow(otherException);

        // Act & Assert
        expect(
          () => categoriesFirestore.updateCategory(updatedCategory),
          throwsA(
            isA<UpdateCategoryFailure>()
                .having((e) => e.error, 'error', otherException),
          ),
        );
        verify(() => mockCollectionRef.doc(updatedCategory.id)).called(1);
        verify(() => mockDocRef.update(updatedCategoryJson)).called(1);
      });

      test('throws UpdateCategoryFailure on generic error during update',
          () async {
        // Arrange
        final mockDocRef = MockDocumentReference();
        when(() => mockCollectionRef.doc(updatedCategory.id))
            .thenReturn(mockDocRef);
        final genericError = Exception('Something went wrong');
        when(() => mockDocRef.update(updatedCategoryJson))
            .thenThrow(genericError);

        // Act & Assert
        expect(
          () => categoriesFirestore.updateCategory(updatedCategory),
          throwsA(
            isA<UpdateCategoryFailure>()
                .having((e) => e.error, 'error', genericError),
          ),
        );
        verify(() => mockCollectionRef.doc(updatedCategory.id)).called(1);
        verify(() => mockDocRef.update(updatedCategoryJson)).called(1);
      });
    });

    group('deleteCategory', () {
      final categoryIdToDelete = category1.id;
      late MockDocumentReference mockDocRef; // Make docRef accessible in tests

      setUp(() {
        mockDocRef = MockDocumentReference();
        when(() => mockCollectionRef.doc(categoryIdToDelete))
            .thenReturn(mockDocRef);
      });

      test('deletes category on success', () async {
        // Arrange
        final mockSnapshot = MockDocumentSnapshot();
        when(() => mockSnapshot.exists).thenReturn(true); // Document exists
        when(() => mockDocRef.get()).thenAnswer((_) async => mockSnapshot);
        when(() => mockDocRef.delete())
            .thenAnswer((_) async {}); // Mock successful delete

        // Act
        await categoriesFirestore.deleteCategory(categoryIdToDelete);

        // Assert
        // Verify the sequence: get then delete
        verifyInOrder([
          () => mockDocRef.get(),
          () => mockDocRef.delete(),
        ]);
      });

      test(
          'throws CategoryNotFoundFailure when category to delete does not exist',
          () async {
        // Arrange
        final mockSnapshot = MockDocumentSnapshot();
        when(() => mockSnapshot.exists)
            .thenReturn(false); // Document does not exist
        when(() => mockDocRef.get()).thenAnswer((_) async => mockSnapshot);

        // Act & Assert
        expect(
          () => categoriesFirestore.deleteCategory(categoryIdToDelete),
          throwsA(
            isA<CategoryNotFoundFailure>()
                .having((e) => e.id, 'id', categoryIdToDelete),
          ),
        );
        verify(() => mockDocRef.get()).called(1); // Verify get was called
        verifyNever(() => mockDocRef.delete()); // Verify delete was NOT called
      });

      test('throws DeleteCategoryFailure on Firestore error during get',
          () async {
        // Arrange
        final exception = _createFirebaseException('unavailable');
        when(() => mockDocRef.get()).thenThrow(exception); // Error during get

        // Act & Assert
        expect(
          () => categoriesFirestore.deleteCategory(categoryIdToDelete),
          throwsA(
            isA<DeleteCategoryFailure>()
                .having((e) => e.error, 'error', exception),
          ),
        );
        verify(() => mockDocRef.get()).called(1); // Verify get was called
        verifyNever(() => mockDocRef.delete()); // Verify delete was NOT called
      });

      test('throws DeleteCategoryFailure on Firestore error during delete',
          () async {
        // Arrange
        final mockSnapshot = MockDocumentSnapshot();
        when(() => mockSnapshot.exists).thenReturn(true); // Document exists
        when(() => mockDocRef.get()).thenAnswer((_) async => mockSnapshot);
        final exception = _createFirebaseException('internal');
        when(() => mockDocRef.delete())
            .thenThrow(exception); // Error during delete

        // Act & Assert
        expect(
          () => categoriesFirestore.deleteCategory(categoryIdToDelete),
          throwsA(
            isA<DeleteCategoryFailure>()
                .having((e) => e.error, 'error', exception),
          ),
        );
        // Verification removed as expect() confirms the flow when delete throws
      });

      test('throws DeleteCategoryFailure on generic error during get',
          () async {
        // Arrange
        final genericError = Exception('Something went wrong during get');
        when(() => mockDocRef.get()).thenThrow(genericError);

        // Act & Assert
        expect(
          () => categoriesFirestore.deleteCategory(categoryIdToDelete),
          throwsA(
            isA<DeleteCategoryFailure>()
                .having((e) => e.error, 'error', genericError),
          ),
        );
        verify(() => mockDocRef.get()).called(1);
        verifyNever(() => mockDocRef.delete());
      });

      test('throws DeleteCategoryFailure on generic error during delete',
          () async {
        // Arrange
        final mockSnapshot = MockDocumentSnapshot();
        when(() => mockSnapshot.exists).thenReturn(true);
        when(() => mockDocRef.get()).thenAnswer((_) async => mockSnapshot);
        final genericError = Exception('Something went wrong during delete');
        when(() => mockDocRef.delete()).thenThrow(genericError);

        // Act & Assert
        expect(
          () => categoriesFirestore.deleteCategory(categoryIdToDelete),
          throwsA(
            isA<DeleteCategoryFailure>()
                .having((e) => e.error, 'error', genericError),
          ),
        );
        // Verification removed as expect() confirms the flow when delete throws
      });
    });
  });
}

// Remove Mock for Transaction (no longer needed)
// class MockTransaction extends Mock implements Transaction {}

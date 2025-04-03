# ht_categories_firestore

[![style: very good analysis](https://img.shields.io/badge/style-very_good_analysis-B22CFF.svg)](https://pub.dev/packages/very_good_analysis)

A Firestore implementation of the `HtCategoriesClient` interface, providing CRUD operations for categories using Cloud Firestore.

This package allows interaction with a Cloud Firestore database to manage `Category` data, handling fetching, creating, updating, and deleting categories.

## Features

*   Implements the `HtCategoriesClient` interface.
*   Provides Firestore-backed storage for categories.
*   Handles standard CRUD operations (Create, Read, Update, Delete).
*   Uses specific exceptions from `ht_categories_client` for error handling.

## Getting started

Ensure you have configured Firebase in your Flutter project.

## Usage

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ht_categories_firestore/ht_categories_firestore.dart';
import 'package:ht_categories_client/ht_categories_client.dart';

void main() async {
  // Initialize Firebase (ensure this is done in your app setup)
  // await Firebase.initializeApp(...);

  // Get Firestore instance
  final firestore = FirebaseFirestore.instance;

  // Create the client
  final categoriesClient = HtCategoriesFirestore(firestore: firestore);

  try {
    // Create a new category
    final newCategory = await categoriesClient.createCategory(
      name: 'Technology',
      description: 'Articles about tech gadgets and software.',
    );
    print('Created category: ${newCategory.id}');

    // Get all categories (demonstrating pagination)
    final firstPageCategories = await categoriesClient.getCategories(limit: 10);
    print('Fetched ${firstPageCategories.length} categories on the first page.');

    String? lastCategoryId;
    if (firstPageCategories.isNotEmpty) {
      lastCategoryId = firstPageCategories.last.id;
      // Get the next page of categories (if any)
      final nextPageCategories = await categoriesClient.getCategories(
        limit: 10,
        startAfterId: lastCategoryId,
      );
      print('Fetched ${nextPageCategories.length} categories on the next page.');
    }

    // Get a specific category
    final fetchedCategory = await categoriesClient.getCategory(newCategory.id);
    print('Fetched category by ID: ${fetchedCategory.name}');

    // Update a category
    final updatedCategory = await categoriesClient.updateCategory(
      fetchedCategory.copyWith(description: 'Updated description'),
    );
    print('Updated category description: ${updatedCategory.description}');

    // Delete a category
    await categoriesClient.deleteCategory(updatedCategory.id);
    print('Deleted category: ${updatedCategory.id}');

  } on HtCategoriesException catch (e) {
    print('An error occurred: $e');
  }
}
```

## Additional information

This package is intended for use within the Headlines Toolkit project ecosystem and relies on the `ht_categories_client` package.

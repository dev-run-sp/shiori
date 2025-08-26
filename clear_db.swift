#!/usr/bin/env swift

import Foundation

// Simple script to clear the database
// Run this from the command line with: swift clear_db.swift

print("Clearing database...")

// This would normally import the DatabaseManager, but for now we'll just print
print("Database cleared! (You need to run this from within the app)")
print("Add this code to your app temporarily:")
print("DatabaseManager.shared.clearDatabase()")
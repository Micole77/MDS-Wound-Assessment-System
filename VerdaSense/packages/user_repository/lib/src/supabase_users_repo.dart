import 'dart:developer';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:user_repository/user_repository.dart';

class SupabaseUsersRepo implements UserRepository{
  final SupabaseClient _supabase;

  SupabaseUsersRepo(this._supabase);
  
  // Sign in with email and password
  @override
  Future<void> signIn(String email, String password) async {
    try{
      await _supabase.auth.signInWithPassword(email: email, password: password);
    } catch (e) {
      log(e.toString());
      rethrow;
    }
  }


  // Log out
  @override
  Future<void> logOut() async {
    await _supabase.auth.signOut();
    log('[SupabaseUsersRepo] Signed out. Waiting for authStateChange...');
  }
  
  
  @override
  Future<void> setUserData(MyUser user) async {
    try {
      await _supabase.from('users').upsert(
        {
          'user_id': user.userId,
          'email': user.email,
          'name': user.name,
        }
      );
    } catch (e) {
      log('Set user data error: $e');
      rethrow;
    }
  }
  
  // Sign Up
  @override
  Future<MyUser> signUp(MyUser myUser, String password) async{
    try{
      final response = await _supabase.auth.signUp(
        email: myUser.email,
        password: password,
        data: {
          'name': myUser.name,
        },
      );

      final userId = response.user?.id;
      if (userId == null) {
        throw Exception('Sign up failed.');
      }

      myUser.userId = userId;

      // Insert into users table
      await setUserData(myUser); 
      return myUser;
    } catch (e) {
      log('SignUp error: $e');
      rethrow;
    }
  } 
  
  @override
  Stream<MyUser?> get user {
    return _supabase.auth.onAuthStateChange.asyncMap((event) async {
      final session = event.session;
      if (session == null) return MyUser.empty;

      final userId = session.user.id;
      log('[SupabaseUsersRepo] Auth session active. User ID: $userId');

      // Retry up to 3 times with small delay
      for (int i = 0; i < 3; i++) {
        final response = await _supabase.from('users').select().eq('user_id', userId).maybeSingle();
        if (response != null) {
          log('[SupabaseUsersRepo] User data fetched: $response');
          return MyUser.fromEntity(MyUserEntity.fromDocument(response));
        }
        await Future.delayed(const Duration(milliseconds: 500));
      }

      log('[SupabaseUsersRepo] User not yet created → returning MyUser.empty');
      return MyUser.empty;
    });
  }

}
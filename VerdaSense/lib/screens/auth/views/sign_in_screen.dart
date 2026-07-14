import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:verdasense/blocs/authentication_bloc/authentication_bloc.dart';
import 'package:verdasense/components/my_app_bar.dart';
import 'package:verdasense/components/my_text_field.dart';
import 'package:verdasense/screens/auth/blocs/sign_in_bloc/sign_in_bloc.dart';
import 'package:verdasense/screens/auth/blocs/sign_up_bloc/sign_up_bloc.dart';
import 'package:verdasense/screens/auth/views/sign_up_screen.dart';
import 'package:verdasense/screens/home/views/app_shell.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {

  final passwordController = TextEditingController();
  final emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool signInRequired = false;
  IconData iconPassword = CupertinoIcons.eye_fill;
  bool obscurePassword = true;
  String? _errorMsg;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Sign In app bar
      appBar: const MyAppBar(title: "Sign In"),

      body: MultiBlocListener(
        listeners: [
          BlocListener<AuthenticationBloc, AuthenticationState>(
            listener: (context, state) {
              if (state.status == AuthenticationStatus.authenticated) {
                // Replace the entire stack with AppShell for persistent nav
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const AppShell()),
                  (route) => false,
                );
              }
            },
          ),
          BlocListener<SignInBloc, SignInState>(
            listener: (context, state) {
              if (state is SignInSuccess) {
                setState(() => signInRequired = false);
              } else if (state is SignInProcess) {
                setState(() => signInRequired = true);
              } else if (state is SignInFailure) {
                setState(() {
                  signInRequired = false;
                  _errorMsg = 'Invalid email or password';
                });
              }
            },
          ),
        ],

        child: Form(
          key: _formKey,
          child: SafeArea(
            child: Column(
              children: [

                // Top illustration/logo to fill empty space
                Expanded(
                  flex: 3,
                  child: Center(
                    child: const Text(
                      "Welcome Back!",
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                // Form fields and button
                Expanded(
                  flex: 4,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [

                        // Email field
                        const SizedBox(height: 20),
                        SizedBox(
                        width: MediaQuery.of(context).size.width * 0.9,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start, // aligns text to the left
                          children: [
                            const Text(
                              "Email Address",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 0), // spacing between label and field
                            MyTextField(
                              controller: emailController,
                              hintText: 'Enter your email',
                              obscureText: false,
                              keyboardType: TextInputType.emailAddress,
                              // prefixIcon: const Icon(CupertinoIcons.mail_solid),
                              errorMsg: _errorMsg,
                              validator: (val) {
                                if (val!.isEmpty) return 'Please fill in this field';
                                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(val)) {
                                  return 'Please enter a valid email';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                        
                        // Password
                        const SizedBox(height: 20),
                        SizedBox(
                        width: MediaQuery.of(context).size.width * 0.9,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start, // aligns text to the left
                          children: [
                            const Text(
                              "Password",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 0), // spacing between label and field
                            MyTextField(
                              controller: passwordController,
                              hintText: 'Enter your password',
                              obscureText: obscurePassword,
                              keyboardType: TextInputType.visiblePassword,
                              // prefixIcon: const Icon(CupertinoIcons.lock_fill),
                              errorMsg: _errorMsg,
                              validator: (val) {
                                if (val!.isEmpty) return 'Please fill in this field';
                                if (!RegExp(r'^(?=.*?[A-Z])(?=.*?[a-z])(?=.*?[0-9])(?=.*?[!@#\$&*~`)\%\-(_+=;:,.<>/?"[{\]}\|^]).{8,}$').hasMatch(val)) {
                                  return 'Please enter a valid password';
                                }
                                return null;
                              },
                              suffixIcon: IconButton(
                                onPressed: () {
                                  setState(() {
                                    obscurePassword = !obscurePassword;
                                    iconPassword = obscurePassword
                                        ? CupertinoIcons.eye_fill
                                        : CupertinoIcons.eye_slash_fill;
                                  });
                                },
                                icon: Icon(iconPassword),
                              ),
                            ),
                          ],
                        ),
                      ),
                        
                        const SizedBox(height: 20),
                        // Sign In button or loading spinner
                        !signInRequired
                          ? SizedBox(
                              width: MediaQuery.of(context).size.width * 0.5,
                              child: TextButton(
                                onPressed: () {
                                  if (_formKey.currentState!.validate()) {
                                    context.read<SignInBloc>().add(SignInRequired(
                                      emailController.text,
                                      passwordController.text,
                                    ));
                                  }
                                },
                                style: TextButton.styleFrom(
                                  elevation: 3.0,
                                  backgroundColor: Theme.of(context).colorScheme.primary,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(60),
                                  ),
                                ),
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 25, vertical: 5),
                                  child: Text(
                                    'Sign In',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            )
                          : const CircularProgressIndicator(),
                      ],
                    ),
                  ),
                ),

                // Link to Sign Up at bottom center
                Padding(
                  padding: const EdgeInsets.only(bottom: 20.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Don't have an account? "),
                      GestureDetector(
                        onTap: () {
                          Navigator.pushReplacement(
                            context,
                            PageRouteBuilder(
                              pageBuilder: (context, animation, secondaryAnimation) =>
                                  BlocProvider(
                                    create: (context) => SignUpBloc(
                                      context.read<AuthenticationBloc>().userRepository,
                                    ),
                                    child: const SignUpScreen(),
                                  ),
                              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                // Smooth fade transition
                                return FadeTransition(opacity: animation, child: child);
                              },
                              transitionDuration: const Duration(milliseconds: 300),
                            ),
                          );
                        },
                        child: Text(
                          "Sign Up",
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
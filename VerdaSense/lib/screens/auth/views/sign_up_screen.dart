import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:user_repository/user_repository.dart';
import 'package:verdasense/blocs/authentication_bloc/authentication_bloc.dart';
import 'package:verdasense/components/my_app_bar.dart';
import 'package:verdasense/components/my_text_field.dart';
import 'package:verdasense/screens/auth/blocs/sign_in_bloc/sign_in_bloc.dart';
import 'package:verdasense/screens/auth/blocs/sign_up_bloc/sign_up_bloc.dart';
import 'package:verdasense/screens/auth/views/sign_in_screen.dart';
import 'package:verdasense/screens/home/views/app_shell.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {

  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final emailController = TextEditingController();
  final nameController = TextEditingController();

  final _formKey = GlobalKey<FormState>();
  
  IconData iconPassword = CupertinoIcons.eye_fill;
  IconData iconConfirmPassword = CupertinoIcons.eye_fill;
  bool obscurePassword = true;
  bool obscureConfirmPassword = true;
  
  // Password requirement booleans
  bool has8Chars = false;
  bool hasUpperLower = false;
  bool hasNumberSpecial = false;

  bool containsUpperCase = false;
  bool containsLowerCase = false;
  bool containsNumber = false;
  bool containsSpecialChar = false;
  bool contains8Length = false;

  bool signUpRequired = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      //Sign Up app bar
      appBar: MyAppBar(title: "Sign Up"),


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
          BlocListener<SignUpBloc, SignUpState>(
            listener: (context, state) {
              if (state is SignUpSuccess) {
                setState(() {
                  signUpRequired = false;
                });
              } else if (state is SignUpProcess) {
                setState(() {
                  signUpRequired = true;
                });
              } else if (state is SignUpFailure) {
                setState(() {
                  signUpRequired = false;
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
                
                // Form fields and button
                Expanded(
                  child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      
                      // Name SizedBox
                      const SizedBox(height: 10),
                      SizedBox(
                        width: MediaQuery.of(context).size.width * 0.9,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start, // aligns text to the left
                          children: [
                            const Text(
                              "Full Name",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 0), // spacing between label and field
                            MyTextField(
                              controller: nameController,
                              hintText: 'Enter your full name',
                              obscureText: false,
                              keyboardType: TextInputType.name,
                              // prefixIcon: const Icon(CupertinoIcons.person_fill),
                              validator: (val) {
                                if (val!.isEmpty) {
                                  return 'Please fill in this field';
                                } else if (val.length > 30) {
                                  return 'Name too long';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                      
                      // Email field
                      const SizedBox(height: 30),
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
                              validator: (val) {
                                if(val!.isEmpty){
                                  return 'Please fill in this field';
                                } else if (!RegExp(r'^[\w-\.]+@([\w-]+.)+[\w-]{2,4}$').hasMatch(val)) {
                                  return 'Please enter a valid email';
                                }
                                return null;
                              }
                            ),
                          ],
                        ),
                      ),
                      
                      // Password field
                      const SizedBox(height: 30),
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
                              hintText: 'Create a password',
                              obscureText: obscurePassword,
                              keyboardType: TextInputType.visiblePassword,
                              // prefixIcon: const Icon(CupertinoIcons.lock_fill),
                              onChanged: (val) {
                                
                                // 8 or more characters
                                setState(() => has8Chars = val!.length >= 8);

                                // Uppercase & lowercase
                                setState(() => hasUpperLower = 
                                  RegExp(r'(?=.*[A-Z])').hasMatch(val!) &&
                                  RegExp(r'(?=.*[a-z])').hasMatch(val)
                                );

                                // Number & special character
                                setState(() => hasNumberSpecial =
                                  RegExp(r'(?=.*[0-9])').hasMatch(val!) &&
                                  RegExp(r'(?=.*[!@#$&*~`)\%\-(_+=;:,.<>/?"[{\]}\|^])').hasMatch(val)
                                );
                              },
                              
                              suffixIcon: IconButton(
                                onPressed: () {
                                  setState(() {
                                    obscurePassword = !obscurePassword;
                                    if (obscurePassword) {
                                      iconPassword = CupertinoIcons.eye_fill;
                                    } else {
                                      iconPassword = CupertinoIcons.eye_slash_fill;
                                    }
                                  });
                                },
                                icon: Icon(iconPassword),
                              ),

                              validator: (val) {
                                if(val!.isEmpty) {
                                  return 'Please fill in this field';
                                } else if (!RegExp(r'^(?=.*?[A-Z])(?=.*?[a-z])(?=.*?[0-9])(?=.*?[!@#\$&*~`)\%\-(_+=;:,.<>/?"[{\]}\|^]).{8,}$').hasMatch(val)) {
                                  return 'Please enter a valid password';
                                }
                                return null;
                              }
                            ),
                          ],
                        ),
                      ),

                      // Confirm Password field
                      const SizedBox(height: 5),
                      SizedBox(
                        width: MediaQuery.of(context).size.width * 0.9,
                        child: MyTextField(
                          controller: confirmPasswordController,
                          hintText: 'Confirm password',
                          obscureText: obscureConfirmPassword,
                          keyboardType: TextInputType.visiblePassword,
                          // prefixIcon: const Icon(CupertinoIcons.lock_fill),
                          suffixIcon: IconButton(
                            onPressed: () {
                              setState(() {
                                obscureConfirmPassword = !obscureConfirmPassword;
                                iconConfirmPassword = obscureConfirmPassword
                                    ? CupertinoIcons.eye_fill
                                    : CupertinoIcons.eye_slash_fill;
                              });
                            },
                            icon: Icon(iconConfirmPassword),
                          ),
                          validator: (val) {
                            if (val!.isEmpty) return 'Please confirm your password';
                            if (val != passwordController.text) return 'Passwords do not match';
                            return null;
                          },
                        ),
                      ),
                      
                      // Requirements for the password
                      const SizedBox(height: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Password must include: ",
                            style: TextStyle(
                              fontWeight: FontWeight.bold
                            ),
                          ),

                          const SizedBox(height: 5),
                          _buildPasswordRequirement("8 or more characters", has8Chars),
                          _buildPasswordRequirement("Uppercase & Lowercase letter", hasUpperLower),
                          _buildPasswordRequirement("At least one number & special character", hasNumberSpecial),
                        ],
                      ),

                      
                      // Sign-Up button
                      const SizedBox(height: 30),
                      SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                      !signUpRequired
                        ? SizedBox(
                          width: MediaQuery.of(context).size.width * 0.5,
                          child: TextButton(
                            onPressed: () {
                              if (_formKey.currentState!.validate()) {
                                // Show the Terms & Conditions dialog when user clicks the Sign Up button
                                _showTermsDialog();
                              }
                            },

                            style: TextButton.styleFrom(
                              elevation: 3.0,
                              backgroundColor: Theme.of(context).colorScheme.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(60)
                              )
                            ),

                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 25, vertical: 5),
                              child: Text(
                                'Sign Up',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600
                                ),
                              ),
                            )
                          ),
                        )
                      : const CircularProgressIndicator(),
                      ],
                    ),
                  ),
                ),

                // Link to Sign In at bottom center
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: // Link to Sign In Screen
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text("Already have an account? "),
                        GestureDetector(
                          onTap: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => BlocProvider(
                                    create: (context) => SignInBloc(
                                      context.read<AuthenticationBloc>().userRepository,
                                    ),
                                    child: const SignInScreen()),
                              )
                            );
                          },
                          child: Text(
                            "Sign In",
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
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


  // Helper widget
  Widget _buildPasswordRequirement(String text, bool isMet) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 6),
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: isMet ? Colors.green : Colors.grey,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: isMet ? Colors.green : Colors.grey[700],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showTermsDialog() async {
    bool localAccepted = false;

    return showDialog<void>(
      context: context,
      barrierDismissible: false,  // User must interact with the dialog
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Terms & Conditions'),
              content: SingleChildScrollView(
                child: ListBody(
                  children: [
                    const Text(
                      "Please read and accept the following terms to continue:",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "• This app is a Decision Support Tool, NOT a diagnostic tool.\n"
                      "• Results must be verified by a healthcare professional.\n"
                      "• AI models may provide incorrect segmentations.\n"
                      "• Data may be used for model retraining to improve accuracy.",
                      style: TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 15),
                    Row(
                      children: [
                        Checkbox(
                          value: localAccepted,
                          onChanged: (bool? value) {
                            setDialogState((){
                              localAccepted = value ?? false;
                            });
                          },
                        ),
                        const Expanded(
                          child: Text("I accept the Terms of Use and Medical Disclaimer"),
                        ),
                      ],
                    ),
                  ]
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                ElevatedButton(
                  onPressed: localAccepted 
                    ? () {
                      Navigator.of(context).pop();
                      _executeSignUp(); // Call the sign up logic
                    } : null, // Disable if not check
                  child: const Text('Accept & Sign Up'),
                ),
              ],
            );
        });
      }
    );
  }

  // Sign Up Logic
  void _executeSignUp() {
    MyUser myUser = MyUser.empty;
    myUser.email = emailController.text;
    myUser.name = nameController.text;

    context.read<SignUpBloc>().add(
      SignUpRequired(myUser, passwordController.text),
    );
  }
}
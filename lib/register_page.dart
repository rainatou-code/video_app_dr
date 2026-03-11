import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  // Définition des contrôleurs
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nomController = TextEditingController();
  final _prenomController = TextEditingController();
  final _phoneController = TextEditingController();
  final _ageController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nomController.dispose();
    _prenomController.dispose();
    _phoneController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    // --- VALIDATION LOCALE ---
    if (email.isEmpty || !email.contains('@') || !email.contains('.')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Veuillez entrer une adresse email valide.")),
      );
      return;
    }
    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Le mot de passe doit contenir au moins 6 caractères.")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Création du compte dans Auth
      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // 2. Enregistrement dans Firestore
      await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
        'nom': _nomController.text.trim(),
        'prenom': _prenomController.text.trim(),
        'email': email,
        'telephone': _phoneController.text.trim(),
        'age': int.tryParse(_ageController.text.trim()) ?? 0,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 3. DECONNEXION IMMEDIATE
      // Force l'utilisateur à se connecter manuellement pour valider son compte
      await FirebaseAuth.instance.signOut();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Compte créé avec succès ! Connectez-vous."),
            backgroundColor: Colors.green,
          ),
        );
        // 4. Retour à la page Login
        Navigator.pop(context);
      }
    } on FirebaseAuthException catch (e) {
      // --- GESTION DES ERREURS FIREBASE ---
      String message = "Une erreur est survenue";
      if (e.code == 'invalid-email') message = "L'adresse email est mal formatée.";
      if (e.code == 'email-already-in-use') message = "Cet email est déjà utilisé par un autre compte.";
      if (e.code == 'weak-password') message = "Le mot de passe est trop faible.";

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur technique : $e"), backgroundColor: Colors.orange),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Inscription")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                  controller: _nomController,
                  decoration: const InputDecoration(labelText: "Nom", border: OutlineInputBorder())
              ),
              const SizedBox(height: 10),
              TextField(
                  controller: _prenomController,
                  decoration: const InputDecoration(labelText: "Prénom", border: OutlineInputBorder())
              ),
              const SizedBox(height: 10),
              TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress, // Clavier optimisé
                  decoration: const InputDecoration(labelText: "Email", border: OutlineInputBorder())
              ),
              const SizedBox(height: 10),
              TextField(
                  controller: _passwordController,
                  decoration: const InputDecoration(labelText: "Mot de passe (min. 6 caractères)", border: OutlineInputBorder()),
                  obscureText: true
              ),
              const SizedBox(height: 10),
              TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: "Téléphone", border: OutlineInputBorder())
              ),
              const SizedBox(height: 10),
              TextField(
                  controller: _ageController,
                  decoration: const InputDecoration(labelText: "Âge", border: OutlineInputBorder()),
                  keyboardType: TextInputType.number
              ),
              const SizedBox(height: 20),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                onPressed: _register,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: const Text("CRÉER MON COMPTE"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
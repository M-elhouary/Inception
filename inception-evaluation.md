# Inception — Evaluation Sheet

## Preliminaries

If cheating is suspected, the evaluation stops here. Use the "Cheat" flag to report it. Take this decision calmly, wisely, and please, use this button with caution.

### Preliminary tests (9 points)

- For example, the use of a local .env file to store info is allowed, and/or also the use of docker secrets In case any credentials, API keys, or passwords are available in the git repository and outside of secrets files created during the evaluation, the evaluation stops and the mark is 0.
- Defense can only happen if the evaluated learner or group is present. This way everybody learns by sharing knowledge with each other.
- If no work has been submitted (or wrong files, wrong directory, or wrong filenames), the grade is 0, and the evaluation process ends.
- For this project, you have to clone their Git repository on their station.

## General instructions (9 points)

- For the entire evaluation process, if you don't know how to check a requirement, or verify anything, the evaluated student has to help you.
- Ensure that all the files required to configure the application are located inside a srcs folder. The srcs folder must be located at the root of the repository.
- Ensure that a Makefile is located at the root of the repository.
- Before starting the evaluation, run this command in the terminal: "docker stop $(docker ps -qa); docker rm $(docker ps -qa); docker rmi -f $(docker images -qa); docker volume rm $(docker volume ls -q); docker network rm $(docker network ls -q) 2>/dev/null"
- Read the docker-compose.yml file. There musn't be 'network: host' in it or 'links:'. Otherwise, the evaluation ends now.
- Read the docker-compose.yml file. There must be 'network(s)' in it. Otherwise, the evaluation ends now.
- Examine the Makefile and all the scripts in which Docker is used. There musn't be '--link' in any of them. Otherwise, the evaluation ends now.
- Examine the Dockerfiles. If you see 'tail -f' or any command run in background in any of them in the ENTRYPOINT section, the evaluation ends now. Same thing if 'bash' or 'sh' are used but not for running a script (e.g, 'nginx & bash' or 'bash').
- If the entrypoint is a script (e.g., ENTRYPOINT ["sh", "my_entrypoint.sh"], ENTRYPOINT ["bash", "my_entrypoint.sh"]), ensure it runs no program in background (e.g, 'nginx & bash').
- Examine all the scripts in the repository. Ensure none of them runs an infinite loop. The following are a few examples of prohibited commands: 'sleep infinity', 'tail -f /dev/null', 'tail -f /dev/random'
- Run the Makefile.

## Mandatory part

This project consists in setting up a small infrastructure composed of different services using docker compose. Ensure that all the following points are correct.

### Project overview (9 points)

- The evaluated person has to explain to you in simple terms:
  - How Docker and docker compose work
  - The difference between a Docker image used with docker compose and without docker compose
  - The benefit of Docker compared to VMs
  - The pertinence of the directory structure required for this project (an example is provided in the subject's PDF file).

### README check (5 points)

- Ensure that a README.md file is present at the root of the repository.
- The very first line must follow the required format: "This project has been created as part of the 42 curriculum by \<login...>" (italicized).
- Check that the README contains at least the required sections: Description, Instructions, Resources (with explanation of how AI was used).
- If any of these elements are missing, the evaluation ends now.

### Documentation check (5 points)

- Ensure that both USER_DOC.md and DEV_DOC.md files are present at the root of the repository.
- USER_DOC.md must provide basic usage instructions for an end user or administrator (start/stop the stack, access the website and admin panel, manage credentials, basic checks).
- DEV_DOC.md must provide developer-oriented instructions (prerequisites, setup, Makefile usage, docker compose commands, data persistence).
- If any of these files are missing or empty, the review ends now.

### Simple setup (9 points)

- Ensure that NGINX can be accessed by port 443 only. Once done, open the page.
- Ensure that a SSL/TLS certificate is used.
- Ensure that the WordPress website is properly installed and configured (you shouldn't see the WordPress Installation page). To access it, open https://login.42.fr in your browser, where login is the login of the evaluated student. You shouldn't be able to access the site via http://login.42.fr. If something doesn't work as expected, the evaluation process ends now.

### Docker Basics (9 points)

- Start by checking the Dockerfiles. There must be one Dockerfile per service. Ensure that the Dockerfiles are not empty files. If it's not the case or if a Dockerfile is missing, the evaluation process ends now.
- Make sure the evaluated student has written their own Dockerfiles and built their own Docker images. Indeed, it is forbidden to use ready-made ones or to use services such as DockerHub.
- Ensure that every container is built from the penultimate stable version of Alpine/Debian. If a Dockerfile does not start with 'FROM alpine:X.X.X' or 'FROM debian:XXXXX', or any other local image, the evaluation process ends now.
- The Docker images must have the same name as their corresponding service. Otherwise, the evaluation process ends now.
- Ensure that the Makefile has set up all the services via docker compose. This means that the containers must have been built using docker compose and that no crash happened. Otherwise, the evaluation process ends.

### Docker Network (9 points)

- Ensure that docker-network is used by checking the docker-compose.yml file. Then run the 'docker network ls' command to verify that a network is visible.
- The evaluated student has to give you a simple explanation of docker-network. If any of the above points is not correct, the evaluation process ends now.

### NGINX with SSL/TLS (9 points)

- Ensure that there is a Dockerfile.
- Using the 'docker compose ps' command, ensure that the container was created (using the flag '-p' is authorized if necessary).
- Try to access the service via http (port 80) and verify that you cannot connect.
- Open https://login.42.fr/ in your browser, where login is the login of the evaluated student. The displayed page must be the configured WordPress website (you shouldn't see the WordPress Installation page).
- The use of a TLS v1.2/v1.3 certificate is mandatory and must be demonstrated. The SSL/TLS certificate doesn't have to be recognized. A self-signed certificate warning may appear. If any of the above points is not clearly explained and correct, the evaluation process ends now.

### WordPress with php-fpm and its volume (9 points)

- Ensure that there is a Dockerfile.
- Ensure that there is no NGINX in the Dockerfile.
- Using the 'docker compose ps' command, ensure that the container was created (using the flag '-p' is authorized if necessary).
- Ensure that there is a Volume. To do so: Run the command 'docker volume ls' then 'docker volume inspect \<volume name>'. Verify that the result in the standard output contains the path '/home/login/data/', where login is the login of the evaluated student.
- Ensure that you can add a comment using the available WordPress user.
- Sign in with the administrator account to access the Administration dashboard. The Admin username must not include 'admin' or 'Admin' (e.g., admin, administrator, Admin-login, admin-123, and so forth).
- From the Administration dashboard, edit a page. Verify on the website that the page has been updated. If any of the above points is not correct, the evaluation process ends now.

### MariaDB and its volume (9 points)

- Ensure that there is a Dockerfile.
- Ensure that there is no NGINX in the Dockerfile.
- Using the 'docker compose ps' command, ensure that the container was created (using the flag '-p' is authorized if necessary).
- Ensure that there is a Volume. To do so: Run the command 'docker volume ls' then 'docker volume inspect \<volume name>'. Verify that the result in the standard output contains the path '/home/login/data/', where login is the login of the evaluated student.
- The evaluated student must be able to explain you how to login into the database. Verify that the database is not empty. If any of the above points is not correct, the evaluation process ends now.

### Persistence! (9 points)

- This part is pretty straightforward. You have to reboot the virtual machine. Once it has restarted, launch docker compose again. Then, verify that everything is functional, and that both WordPress and MariaDB are configured. The changes you made previously to the WordPress website should still be here. If any of the above points is not correct, the evaluation process ends now.

## Bonus

Evaluate the bonus part if, and only if, the mandatory part has been entirely and perfectly done, and the error management handles unexpected or bad usage. In case all the mandatory points were not passed during the defense, bonus points must be totally ignored.

### Bonus (25 points)

005

Add 1 point per bonus authorized in the subject. Verify and test the proper functioning and implementation of each extra service. For the free choice service, the evaluated student has to give you a simple explanation about how it works and why they think it is useful.

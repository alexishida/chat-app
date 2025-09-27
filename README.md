# Guia: Como Criar um Chat App com Ruby on Rails 8, ActionCable e Turbo Streams

Este guia irá te ensinar a construir uma aplicação de chat multi-usuário, simples mas totalmente funcional, usando as funcionalidades em tempo real do Rails 8.

## Sumário

*   [Passo 1: Configuração Inicial](#passo1)
*   [Passo 2: Geração de Modelos e Banco de Dados](#passo2)
*   [Passo 3: Configuração das Rotas](#passo3)
*   [Passo 3.5: Configurando Autenticação Simples](#passo35)
*   [Passo 4: Atualização dos Controladores](#passo4)
*   [Passo 5: Criação e Atualização das Views](#passo5)
*   [Passo 6: Executando a Aplicação](#passo6)
*   [Como Funciona](#como-funciona)

## Passo 1: Configuração Inicial

Primeiro, você precisará ter o Ruby e o Rails instalados. Abra o seu terminal e execute o seguinte comando para criar uma nova aplicação. Vamos usar o PostgreSQL como banco de dados e o Tailwind CSS para o estilo.

```
rails new chat_app --css tailwind --database postgresql
cd chat_app
```

## Passo 2: Geração de Modelos e Banco de Dados

Agora, vamos gerar os modelos necessários: `Room`, `Message` e `User`.

```
# Gerar o modelo Room
rails generate model Room name:string

# Gerar o modelo User
rails generate model User name:string

# Gerar o modelo Message
rails generate model Message content:text room:references user:references

# Migrar o banco de dados para criar as tabelas
rails db:migrate
```

Depois de migrar, atualize os arquivos dos modelos para definir as associações.

```
# app/models/room.rb
class Room < ApplicationRecord
  has_many :messages, dependent: :destroy
end

# app/models/user.rb
class User < ApplicationRecord
  has_many :messages
end

# app/models/message.rb
class Message < ApplicationRecord
  belongs_to :room
  belongs_to :user

  after_create_commit { broadcast_to_room }

  private

  def broadcast_to_room
    broadcast_append_to self.room, target: "messages", partial: "messages/message", locals: { message: self, current_user: self.user }
  end
end
```

## Passo 3: Configuração das Rotas

Edite o arquivo `config/routes.rb` para definir as rotas do nosso chat e do sistema de login.

```
# config/routes.rb
Rails.application.routes.draw do
  root "rooms#index"

  get 'login', to: 'sessions#new'
  post 'login', to: 'sessions#create'
  delete 'logout', to: 'sessions#destroy'

  resources :rooms, only: [:index, :show] do
    resources :messages, only: [:create]
  end
end
```

## Passo 3.5: Configurando Autenticação Simples

Para que múltiplos usuários funcionem, precisamos saber quem está logado. Vamos criar um sistema de login simples baseado em sessão.

1.  **Crie o SessionsController:**

    ```
    rails generate controller Sessions new create destroy
    ```

2.  **Adicione os métodos de ajuda ao ApplicationController:**
    Abra `app/controllers/application_controller.rb` e adicione o seguinte código. Estes métodos nos ajudarão a encontrar o `current_user` e a proteger páginas.

    ```
    # app/controllers/application_controller.rb
    class ApplicationController < ActionController::Base
      helper_method :current_user, :logged_in?

      def current_user
        @current_user ||= User.find(session[:user_id]) if session[:user_id]
      end

      def logged_in?
        !!current_user
      end

      def require_user
        unless logged_in?
          flash[:alert] = "Você deve estar logado para acessar esta página."
          redirect_to login_path
        end
      end
    end
    ```

3.  **Implemente a lógica no SessionsController:**

    ```
    # app/controllers/sessions_controller.rb
    class SessionsController < ApplicationController
      def new
      end

      def create
        user = User.find_by(name: params[:session][:name])
        if user
          session[:user_id] = user.id
          flash[:notice] = "Login efetuado com sucesso!"
          redirect_to root_path
        else
          flash.now[:alert] = "Usuário não encontrado."
          render 'new', status: :unprocessable_entity
        end
      end

      def destroy
        session[:user_id] = nil
        flash[:notice] = "Logout efetuado."
        redirect_to login_path
      end
    end
    ```


## Passo 4: Atualização dos Controladores

Agora, vamos proteger nossos controladores e usar o `current_user` para criar mensagens.

### `app/controllers/rooms_controller.rb`

Adicione um `before_action` para garantir que apenas usuários logados possam ver as salas.

```
class RoomsController < ApplicationController
  before_action :require_user

  def index
    @rooms = Room.all
  end

  def show
    @room = Room.find(params[:id])
    @message = Message.new(room: @room)
    @messages = @room.messages.includes(:user)
  end
end
```

### `app/controllers/messages_controller.rb`

Modifique o método `create` para usar o `current_user`.

```
class MessagesController < ApplicationController
  before_action :require_user

  def create
    @room = Room.find(params[:room_id])
    @message = @room.messages.build(message_params.merge(user: current_user))
    @message.save
  end

  private

  def message_params
    params.require(:message).permit(:content)
  end
end
```

## Passo 5: Criação e Atualização das Views

Vamos criar a página de login e ajustar as outras views para a nova funcionalidade.

1.  **Crie a View de Login:**

    ```
    # app/views/sessions/new.html.erb
    <div class="container mx-auto p-4 max-w-sm text-center">
      <h1 class="text-3xl font-bold mb-6">Login</h1>
      <%= form_with(scope: :session, url: login_path, local: true, class: "space-y-4") do |f| %>
        <div>
          <%= f.label :name, "Nome de Usuário", class: "block text-left font-medium text-gray-700" %>
          <%= f.text_field :name, class: "w-full p-2 mt-1 border rounded-lg", required: true %>
        </div>
        <%= f.submit "Entrar", class: "w-full py-3 px-6 bg-blue-500 hover:bg-blue-600 text-white font-semibold rounded-lg shadow-md cursor-pointer" %>
      <% end %>
    </div>
    ```

2.  **Atualize o Layout da Aplicação:**
    Adicione uma barra de navegação e um local para exibir mensagens de alerta/notificação em `app/views/layouts/application.html.erb`.

    ```
    <!DOCTYPE html>
    <html>
      <head>
        <title>ChatApp</title>
        <meta name="viewport" content="width=device-width,initial-scale=1">
        <%= csrf_meta_tags %>
        <%= csp_meta_tag %>
        <%= stylesheet_link_tag "tailwind", "inter-font", "data-turbo-track": "reload" %>

        <%= stylesheet_link_tag "application", "data-turbo-track": "reload" %>
        <%= javascript_importmap_tags %>
      </head>

      <body class="bg-gray-50">
        <nav class="bg-white shadow-sm">
          <div class="container mx-auto px-4 py-3 flex justify-between items-center">
            <%= link_to "ChatApp", root_path, class: "text-xl font-bold text-blue-600" %>
            <div>
              <% if logged_in? %>
                <span class="mr-4 text-gray-700">Olá, <strong><%= current_user.name %></strong></span>
                <%= link_to "Sair", logout_path, data: { turbo_method: :delete }, class: "text-red-500 hover:underline" %>
              <% else %>
                <%= link_to "Login", login_path, class: "text-blue-600 hover:underline" %>
              <% end %>
            </div>
          </div>
        </nav>

        <div class="container mx-auto p-4">
          <% if flash[:notice] %>
            <div class="bg-green-100 border border-green-400 text-green-700 px-4 py-3 rounded relative mb-4" role="alert">
              <%= flash[:notice] %>
            </div>
          <% end %>
          <% if flash[:alert] %>
            <div class="bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded relative mb-4" role="alert">
              <%= flash[:alert] %>
            </div>
          <% end %>

          <%= yield %>
        </div>
      </body>
    </html>
    ```

3.  **Ajuste a View da Sala de Chat:** O arquivo `app/views/rooms/show.html.erb` permanece quase o mesmo.

    ```
    # app/views/rooms/show.html.erb
    <div class="container mx-auto p-4 max-w-2xl">
      <h1 class="text-3xl font-bold mb-4 text-center"><%= @room.name %></h1>

      <div class="bg-white p-6 rounded-xl shadow-lg h-[60vh] overflow-y-auto mb-4 flex flex-col-reverse">
        <div id="messages">
          <% @messages.reverse.each do |message| %>
            <%= render "messages/message", message: message, current_user: current_user %>
          <% end %>
        </div>
      </div>

      <%= form_with model: [@room, @message], html: { data: { turbo_stream: true } }, class: "flex items-center space-x-2" do |form| %>
        <%= form.text_field :content, placeholder: "Escreva uma mensagem...", class: "flex-1 p-3 rounded-lg border border-gray-300 focus:outline-none focus:ring-2 focus:ring-blue-500", autocomplete: "off" %>
        <%= form.submit "Enviar", class: "py-3 px-6 bg-blue-500 hover:bg-blue-600 text-white font-semibold rounded-lg shadow-md transition duration-300 cursor-pointer" %>
      <% end %>

      <%= turbo_stream_from @room %>
    </div>
    ```

4.  **Dê Estilo às Mensagens:** Atualize `app/views/messages/_message.html.erb` para alinhar as mensagens do usuário atual à direita.

    ```
    # app/views/messages/_message.html.erb
    <% is_current_user = (message.user == current_user) %>
    <div class="flex <%= is_current_user ? 'justify-end' : 'justify-start' %> mb-3">
      <div class="rounded-xl shadow-sm p-3 max-w-md <%= is_current_user ? 'bg-blue-500 text-white' : 'bg-gray-100' %>">
        <% unless is_current_user %>
          <p class="text-xs font-semibold text-blue-400"><%= message.user.name %></p>
        <% end %>
        <p class="font-medium <%= is_current_user ? 'text-white' : 'text-gray-800' %>"><%= message.content %></p>
        <p class="text-xs text-right mt-1 <%= is_current_user ? 'text-blue-200' : 'text-gray-400' %>">
          <%= time_ago_in_words(message.created_at) %>
        </p>
      </div>
    </div>
    ```


## Passo 6: Executando a Aplicação

Para testar, crie algumas salas e alguns usuários.

```
rails console
# No console, crie as salas
Room.create(name: "Geral")
Room.create(name: "Desenvolvimento")

# Crie alguns usuários para o chat
User.create(name: "Ana")
User.create(name: "Carlos")
```

Agora, inicie o servidor Rails.

```
rails server
```

Abra o seu navegador em `http://localhost:3000`. Você será direcionado para a página de login. Use "Ana" para logar em uma janela e "Carlos" em outra para ver a mágica acontecer!

## Como Funciona

*   O usuário primeiro faz login através do `SessionsController`, que armazena o `user_id` na sessão.
*   O `ApplicationController` usa o `user_id` da sessão para encontrar o `current_user`.
*   Quando o usuário envia uma mensagem, o `MessagesController` usa o `current_user` para associar a mensagem ao autor correto.
*   O callback no modelo `Message` transmite a nova mensagem para todos os clientes conectados à sala via ActionCable e Turbo Streams.
*   A view `_message.html.erb` usa a variável `current_user` para decidir como estilizar e alinhar a mensagem, criando uma experiência de chat familiar.
require 'sinatra'
require 'mysql2'
require 'base64'
require 'prawn'
require 'dotenv/load'

def db
  @db ||= Mysql2::Client.new(
    host: ENV['DB_HOST'],
    username: ENV['DB_USER'],
    password: ENV['DB_PASS'],
    database: ENV['DB_NAME'],
    encoding: "binary",
    reconnect: true,
    symbolize_keys: true
  )
end

#Routing
get '/' do
  erb:login
end

#get '/supervisor' do
  #erb:supervisor_dashboard
#end

get '/operator' do
  erb:operator_dashboard
end

get '/login_gagal' do
  erb:login_gagal
end

#tangkap ERROR
error 403 do
  erb :akses_ditolak
end

before '/manager*' do
  halt 403 unless request.referer&.include?("/")
end

before '/supervisor*' do
  halt 403 unless request.referer&.include?("/")
end

before '/operator*' do
  halt 403 unless request.referer&.include?("/")
end

#Data - MANAGER
post '/manager' do

  id      = params['id']
  nama    = params['nama']
  email   = params['email']
  shift   = params['shift']
  role    = params['role']
  foto_file = params[:foto][:tempfile]
  foto_data = foto_file.read
  status  = params['status']

  if nama.empty? || email.empty? || shift.empty? || role.empty? || status.empty?
    redirect '/manager'
  end

  case role
  when 'Manager'
    data = db.prepare("INSERT INTO manager(id, nama, email, shift, role, foto, status) VALUES(?, ?, ?, ?, ?, ?, ?)")
    data.execute(id, nama, email, shift, role, foto_data, status)
  when 'Supervisor'
    data1 = db.prepare("INSERT INTO supervisor(id, nama, email, shift, role, foto, status) VALUES(?, ?, ?, ?, ?, ?, ?)")
    data1.execute(id, nama, email, shift, role, foto_data, status)
  when 'Operator'
    data2 = db.prepare("INSERT INTO operator(id, nama, email, shift, role, foto, status) VALUES(?, ?, ?, ?, ?, ?, ?)")
    data2.execute(id, nama, email, shift, role, foto_data, status)
  end
  redirect '/manager'
end

#Data - LAPORAN OPERATOR
post '/operator' do
  id = params['id']
  nama_lengkap  = params['nama']
  tekanan_darah = params['tekanan_darah']
  apd = params['apd']
  kondisi_fisik  = params['kondisi_fisik']
  kondisi_mental = params['kondisi_mental']
  status  = params['status']
  foto_file = params[:foto][:tempfile]
  foto_data = foto_file.read
  catatan = params['catatan']

  data3 = db.prepare("INSERT INTO laporan_operator(id, nama_lengkap, tekanan_darah, apd, kondisi_fisik, kondisi_mental, status, foto, catatan) VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?)")
  data3.execute(id, nama_lengkap, tekanan_darah, apd, kondisi_fisik, kondisi_mental, status, foto_data, catatan)

  redirect '/operator'
end

#Route Data
get '/manager' do

  @managers = db.query("SELECT * FROM manager").to_a
  @supervisors = db.query("SELECT * FROM supervisor").to_a
  @operators = db.query("SELECT * FROM operator").to_a
  @laporan_operator = db.query("SELECT * FROM laporan_operator").to_a
  @laporan_operator0 = db.query("SELECT * FROM laporan_operator where status='Hadir'")
  @laporan_operator1 = db.query("SELECT * FROM laporan_operator where status='Izin'")
  @laporan_operator2 = db.query("SELECT * FROM laporan_operator where status='Cuti'")
  @status_hadir = @laporan_operator0.count
  @status_izin = @laporan_operator1.count
  @status_cuti = @laporan_operator2.count
  @operator = @operators.count
  erb :manager_dashboard
end

get '/supervisor' do
  @laporan_operator = db.query("SELECT * FROM laporan_operator").to_a
  erb :supervisor_dashboard
end

#Route foto
get '/foto/:role/:id' do
  halt 400 unless %w[manager supervisor operator laporan_operator].include?(params[:role])

  client = Mysql2::Client.new(
    host: ENV['DB_HOST'],
    username: ENV['DB_USER'],
    password: ENV['DB_PASS'],
    database: ENV['DB_NAME'],
    encoding: 'binary',
    cast: false
  )

  table = params[:role]
  id    = params[:id]

  stmt = client.prepare("SELECT foto FROM #{table} WHERE id=?")
  row  = stmt.execute(id).first

  halt 404 unless row && row['foto']

  content_type 'image/jpeg'
  row['foto']
end

#Hapus - MANAGER
get '/hapus_manager/:id' do
  id = params['id']

  sql = db.prepare("DELETE FROM manager WHERE id=?")
  sql.execute(id)
  redirect '/manager'
end

#Hapus - SUPERVISOR
get '/hapus_supervisor/:id' do
  id = params['id']

  sql1 = db.prepare("DELETE FROM supervisor WHERE id=?")
  sql1.execute(id)
  redirect '/manager'
end

#Hapus - OPERATOR
get '/hapus_operator/:id' do
  id = params['id']

  sql2 = db.prepare("DELETE FROM operator WHERE id=?")
  sql2.execute(id)
  redirect '/manager'
end

#LOGIN
post '/login' do
  email = params['email']

  if db.prepare("SELECT id FROM manager WHERE email=?").execute(email).first
    redirect '/manager'
  elsif db.prepare("SELECT id FROM supervisor WHERE email=?").execute(email).first
    redirect '/supervisor'
  elsif db.prepare("SELECT id FROM operator WHERE email=?").execute(email).first
    redirect '/operator'
  else
    redirect '/login_gagal'
  end
end

# Export PDF
get '/export_pdf' do
  @laporan_operator = db.query("SELECT * FROM laporan_operator")

  pdf = Prawn::Document.new
  pdf.text "Laporan Status Kesiapan Harian OPERATOR", size: 20, style: :bold
  pdf.move_down 20

  (@laporan_operator || []).each do |lapor|
    pdf.text "Nama    : #{lapor[:nama_lengkap]}"
    pdf.text "Status  : #{lapor[:status]}"
    pdf.text "Jam     : #{lapor[:jam]}"
    pdf.text "Catatan : #{lapor[:catatan]}"
    pdf.move_down 10
  end

  content_type 'application/pdf'
  attachment 'rekap_kehadiran_pegawai.pdf'
  pdf.render
end

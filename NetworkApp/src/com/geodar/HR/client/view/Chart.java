package com.geodar.HR.client.view;

import java.util.Date;

import com.google.gwt.http.client.Request;
import com.google.gwt.http.client.RequestBuilder;
import com.google.gwt.http.client.RequestCallback;
import com.google.gwt.http.client.RequestException;
import com.google.gwt.http.client.Response;
import com.google.gwt.http.client.URL;
import com.google.gwt.json.client.JSONArray;
import com.google.gwt.json.client.JSONException;
import com.google.gwt.json.client.JSONNumber;
import com.google.gwt.json.client.JSONObject;
import com.google.gwt.json.client.JSONParser;
import com.google.gwt.json.client.JSONValue;
import com.google.gwt.user.client.ui.VerticalPanel;
import com.google.gwt.visualization.client.AbstractDataTable;
import com.google.gwt.visualization.client.AbstractDataTable.ColumnType;
import com.google.gwt.visualization.client.DataTable;
import com.google.gwt.visualization.client.VisualizationUtils;
import com.google.gwt.visualization.client.visualizations.AnnotatedTimeLine;
import com.google.gwt.visualization.client.visualizations.AnnotatedTimeLine.ScaleType;

public class Chart extends VerticalPanel {
	private String query;
	private DataTable data;
	private AnnotatedTimeLine atl = null;
	private String url;

	RequestBuilder builder;

	public Chart(String query, String url) {
		this.query = query;
		this.url = url;
		url = URL.encode(url + query);
		builder = new RequestBuilder(RequestBuilder.GET, url);
		// Create a callback to be called when the visualization API
		// has been loaded.
		Runnable onLoadCallback = new Runnable() {
			public void run() {
				atl = new AnnotatedTimeLine(createTable(), createOptions(), "550px", "300px");
				// Add a chart visualization.
				add(atl);
				updateGraph();
			}
		};

		// Load the visualization api, passing the onLoadCallback to be called
		// when loading is done.
		VisualizationUtils.loadVisualizationApi(onLoadCallback, AnnotatedTimeLine.PACKAGE);


	}

	private AnnotatedTimeLine.Options createOptions() {
		AnnotatedTimeLine.Options options = AnnotatedTimeLine.Options.create();
		options.setDisplayAnnotations(false);
		options.setScaleType(ScaleType.MAXIMIZE);
		return options;
	}

	private AbstractDataTable createTable() {

		data = DataTable.create();
		data.addColumn(ColumnType.DATETIME, "Date");
		data.addColumn(ColumnType.NUMBER, query);
		return data;

	}

	private void updateGraph() {

		// add watch list stock symbols to URL
		System.out.println("Updating graph");
		

		try {
			builder.sendRequest(null, new RequestCallback() {
				public void onError(Request request, Throwable exception) {
					displayError("Couldn't retrieve JSON");
				}

				public void onResponseReceived(Request request, Response response) {
					if (200 == response.getStatusCode()) {
						try {
							// parse the response text into JSON
							JSONValue jsonValue = JSONParser.parseStrict(response.getText());
							System.out.println("response:" + response.getText());
							JSONArray jsonArray = jsonValue.isArray();

							if (jsonArray != null) {
								System.out.println("Got " + jsonArray.toString());
								updateTable(jsonArray);
							} else {
								throw new JSONException();
							}
						} catch (JSONException e) {
							displayError("Could not parse JSON");
							// System.err.println(e.toString());
							// e.printStackTrace();
						}
					} else {
						displayError("Couldn't retrieve JSON (" + response.getStatusText() + ")");
					}
				}

			});
		} catch (RequestException e) {
			displayError("Couldn't retrieve JSON");
		} catch (Exception e) {
			displayError(e.getStackTrace().toString());
		}
	}

	private void displayError(String error) {
		System.out.println(error);
		// errorMsgLabel.setVisible(true);
	}

	private void updateTable(JSONArray array) {
		JSONValue jsonValue;

		for (int i = 0; i < array.size(); i++) {
			JSONObject jsEntry;
			JSONNumber jsVal;

			if ((jsEntry = array.get(i).isObject()) == null) {
				System.out.println("1");
				continue;
			}
			
			if ((jsonValue = jsEntry.get("value")) == null) {
				System.out.println("4");
				continue;
			}
			if ((jsVal = jsonValue.isNumber()) == null) {
				System.out.println("5");
				continue;
			}

			data.addRow();
			data.setValue(data.getNumberOfRows() - 1, 0, new Date());
			data.setValue(data.getNumberOfRows() - 1, 1, jsVal.doubleValue());
			atl.draw(data);
		}
	}

	public String getQuery() {
		return query;
	}

	public void setQuery(String query) {
		this.query = query;
	}

	public String getUrl() {
		return url;
	}

	public void setUrl(String url) {
		this.url = url;
	}

}